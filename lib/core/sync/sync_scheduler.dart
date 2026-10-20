import 'dart:async';
import 'dart:collection';

import '../error/failure.dart';
import '../network/rate_limit_status.dart';
import '../network/rate_limiter.dart';
import '../time/clock.dart';
import 'cancel_token.dart';

/// Prioridad de un trabajo de sincronización (§5.8).
///
/// P3 (historial) es post-MVP.
enum SyncPriority {
  /// P0: lo que el usuario está mirando o un refresco manual.
  visible,

  /// P1: contexto (ronda vecina, rondas actuales del Inicio).
  context,

  /// P2: rondas de la temporada del equipo abierto. Con cupo propio, de a
  /// uno y en pausa con la app en segundo plano.
  team;

  bool get isBackground => index >= team.index;
}

Future<void> _realDelay(Duration duration) => Future<void>.delayed(duration);

/// Cola única de trabajos de una petición: deduplica por clave, atiende por
/// prioridad y en orden de llegada, y limita los trabajos simultáneos. El
/// ritmo total de peticiones lo controla el `RateLimiter` del cliente.
///
/// Los trabajos de segundo plano (P2) tienen además un cupo de
/// [backgroundPerWindow] inicios por [window], corren de a uno (siempre
/// queda lugar para P0/P1) y no empiezan mientras la cola está en pausa.
///
/// Un trabajo que falla con `RateLimitFailure` (HTTP 429) vuelve a la cola
/// con su prioridad y su orden, hasta [maxRateLimitRetries] veces, si la
/// pausa no supera [maxRateLimitWait] y alguien lo sigue esperando. Si un
/// trabajo agota sus reintentos, los 429 de la ventana siguiente fallan sin
/// reintento.
/// Mientras dura la pausa de [rateLimit] no empieza ningún trabajo: al
/// reanudar, la cola elige por prioridad.
class SyncScheduler {
  SyncScheduler({
    this.maxConcurrent = 2,
    this.backgroundPerWindow = 10,
    this.window = const Duration(minutes: 1),
    Clock clock = const SystemClock(),
    Delay delay = _realDelay,
    RateLimitStatus? rateLimit,
  }) : _clock = clock,
       _delay = delay,
       _rateLimit = rateLimit;

  final int maxConcurrent;
  final int backgroundPerWindow;
  final Duration window;
  final Clock _clock;
  final Delay _delay;
  final RateLimitStatus? _rateLimit;

  static const maxBackgroundConcurrent = 1;

  /// Reintentos de un trabajo tras un HTTP 429 (3 intentos en total).
  static const maxRateLimitRetries = 2;

  /// Una pausa más larga (un `Retry-After` de más de 5 min) no se espera
  /// sola: el trabajo falla y queda «Reintentar».
  static const maxRateLimitWait = Duration(minutes: 5);

  final _queue = <_Job>[];
  final _byKey = <String, _Job>{};
  final _backgroundStarts = Queue<DateTime>();
  var _running = 0;
  var _runningBackground = 0;
  var _sequence = 0;
  var _paused = false;
  var _wakeScheduled = false;
  var _rateLimitWakeScheduled = false;

  /// Un trabajo agotó sus reintentos: hasta esta hora (la ventana que sigue
  /// a esa pausa) los 429 no se reintentan. Así un límite persistente lleva
  /// a «Reintentar» en minutos y no encadena las esperas de cada trabajo
  /// (no se reinicia con un trabajo que termina bien: puede no haber
  /// consultado nada).
  DateTime? _noRetryUntil;

  /// Ejecuta [task] o se suma a un trabajo con la misma [key] ya pendiente
  /// o en curso (y le sube la prioridad si todavía está en cola).
  ///
  /// Si [cancelToken] se cancela antes de que el trabajo empiece (o mientras
  /// espera un reintento tras un HTTP 429) y nadie más lo espera, el trabajo
  /// se descarta y el futuro falla con [SyncCancelled]. Un trabajo en curso
  /// no se interrumpe.
  Future<void> run(
    String key,
    SyncPriority priority,
    Future<void> Function() task, {
    CancelToken? cancelToken,
  }) {
    if (cancelToken?.isCancelled ?? false) {
      return Future.error(const SyncCancelled());
    }
    var job = _byKey[key];
    if (job != null) {
      if (priority.index < job.priority.index && _queue.contains(job)) {
        job.priority = priority;
      }
    } else {
      job = _Job(key, priority, task, _sequence++);
      // Un trabajo descartado puede no tener a nadie esperándolo.
      job.completer.future.ignore();
      _byKey[key] = job;
      _queue.add(job);
    }
    job.owners.add(cancelToken);
    cancelToken?.addListener(_dropCancelled);
    _pump();
    return job.completer.future;
  }

  /// Trabajos en cola o en curso (para diagnóstico y tests).
  int get pending => _byKey.length;

  bool get isPaused => _paused;

  /// App en segundo plano: no empiezan trabajos P2 (los P0/P1 siguen).
  void pause() => _paused = true;

  void resume() {
    _paused = false;
    _pump();
  }

  void _dropCancelled() {
    final dropped = [
      for (final job in _queue)
        if (job.isAbandoned) job,
    ];
    for (final job in dropped) {
      _queue.remove(job);
      _byKey.remove(job.key);
      job.completer.completeError(const SyncCancelled());
    }
  }

  void _pump() {
    _queue.sort(
      (a, b) => a.priority != b.priority
          ? a.priority.index - b.priority.index
          : a.sequence - b.sequence,
    );
    if (_queue.isNotEmpty && _waitingRateLimit()) return;
    while (_running < maxConcurrent && _queue.isNotEmpty) {
      final job = _queue.first;
      final background = job.priority.isBackground;
      // La cola está ordenada: detrás de un P2 solo hay otros P2.
      if (background &&
          (_paused ||
              _runningBackground >= maxBackgroundConcurrent ||
              !_takeBackgroundSlot())) {
        return;
      }
      _queue.removeAt(0);
      _running++;
      if (background) _runningBackground++;
      var requeued = false;
      job
          .task()
          .then(
            job.completer.complete,
            onError: (Object error, StackTrace stack) {
              if (_retriesAfterRateLimit(job, error)) {
                requeued = true;
              } else {
                job.completer.completeError(error, stack);
              }
            },
          )
          .whenComplete(() {
            _running--;
            if (background) _runningBackground--;
            // Reencolado, sigue uniendo los pedidos de su clave.
            if (!requeued) _byKey.remove(job.key);
            _pump();
          });
    }
  }

  /// Si el trabajo vuelve a la cola tras un HTTP 429: quedan reintentos,
  /// alguien lo espera y la pausa es razonable.
  bool _retriesAfterRateLimit(_Job job, Object error) {
    if (error is! RateLimitFailure || job.isAbandoned) return false;
    final now = _clock.now();
    final until = _rateLimit?.pausedUntil;
    if (job.rateLimitRetries >= maxRateLimitRetries) {
      _noRetryUntil = (until ?? now).add(window);
      return false;
    }
    final noRetryUntil = _noRetryUntil;
    if (noRetryUntil != null && now.isBefore(noRetryUntil)) return false;
    if (until != null && until.difference(now) > maxRateLimitWait) {
      return false;
    }
    job.rateLimitRetries++;
    _queue.add(job);
    return true;
  }

  /// Consultas en pausa por HTTP 429: no empieza nada (las que empezaran
  /// esperarían en el limitador en orden de llegada) y se vuelve a mirar la
  /// cola al terminar la pausa.
  bool _waitingRateLimit() {
    final until = _rateLimit?.pausedUntil;
    if (until == null) return false;
    if (!_rateLimitWakeScheduled) {
      _rateLimitWakeScheduled = true;
      _delay(until.difference(_clock.now())).then((_) {
        _rateLimitWakeScheduled = false;
        _pump();
      });
    }
    return true;
  }

  /// Registra un inicio P2 si hay cupo en la ventana; si no, programa un
  /// nuevo intento cuando se libere.
  bool _takeBackgroundSlot() {
    final now = _clock.now();
    while (_backgroundStarts.isNotEmpty &&
        !now.isBefore(_backgroundStarts.first.add(window))) {
      _backgroundStarts.removeFirst();
    }
    if (_backgroundStarts.length < backgroundPerWindow) {
      _backgroundStarts.addLast(now);
      return true;
    }
    if (!_wakeScheduled) {
      _wakeScheduled = true;
      _delay(_backgroundStarts.first.add(window).difference(now)).then((_) {
        _wakeScheduled = false;
        _pump();
      });
    }
    return false;
  }
}

class _Job {
  _Job(this.key, this.priority, this.task, this.sequence);

  final String key;
  SyncPriority priority;
  final Future<void> Function() task;
  final int sequence;
  final completer = Completer<void>();

  /// Veces que volvió a la cola tras un HTTP 429.
  var rateLimitRetries = 0;

  /// Quienes lo esperan; `null` = sin posibilidad de cancelar.
  final owners = <CancelToken?>[];

  bool get isAbandoned =>
      owners.every((token) => token != null && token.isCancelled);
}
