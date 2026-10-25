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
/// pausa no supera [maxRateLimitWait] y alguien lo sigue esperando.
/// Mientras dura la pausa de [rateLimit] no empieza ningún trabajo: al
/// reanudar, la cola elige por prioridad.
///
/// Fase R3.1: después de un 429, empieza un solo trabajo por vez hasta una
/// respuesta aceptada (la sonda). Bloqueo persistente
/// ([isRateLimitBlocked]): con [persistentRateLimits] 429 seguidos del
/// limitador (de cualquier trabajo) ningún 429 se reintenta; si la sonda
/// responde, todo sigue; si vuelve a dar 429, los trabajos en cola fallan
/// sin consultar y, hasta que termine esa pausa, también los pedidos nuevos
/// (una pantalla que encadena pedidos tras un fallo no espera otra pausa de
/// 240 s por cada uno). Pasada la pausa, el primer pedido es otra sonda.
///
/// Fase R4 (Web): un trabajo que falla con la sospecha de un 429 oculto por
/// CORS (`NetworkFailure.suspectedRateLimit`) vuelve a la cola una sola vez
/// y espera la espera de sospecha del limitador; mientras el episodio siga
/// abierto, de a uno. Si la sonda vuelve a fallar por red, los que esperaban
/// ese reintento terminan con el mismo error sin consultar. No cuenta como
/// 429: no cambia los reintentos ni el bloqueo persistente.
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

  /// 429 seguidos que confirman un bloqueo persistente: más de 3 min de
  /// límite (pausas de 60 y 120 s y el tercero), el escalón en que el
  /// limitador pasa a 240 s.
  static const persistentRateLimits = maxRateLimitRetries + 1;

  final _queue = <_Job>[];
  final _byKey = <String, _Job>{};
  final _backgroundStarts = Queue<DateTime>();
  var _running = 0;
  var _runningBackground = 0;
  var _sequence = 0;
  var _paused = false;
  var _wakeScheduled = false;
  var _rateLimitWakeScheduled = false;

  /// Falló la sonda de un bloqueo persistente: hasta esta hora (el fin de
  /// la pausa de ese 429) los pedidos nuevos fallan sin consultar.
  DateTime? _failFastUntil;

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
    final failFastUntil = _failFastUntil;
    if (job == null &&
        failFastUntil != null &&
        _clock.now().isBefore(failFastUntil)) {
      return Future.error(_persistentBlock);
    }
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

  /// TheSportsDB sigue limitando: [persistentRateLimits] o más 429 seguidos.
  bool get isRateLimitBlocked =>
      (_rateLimit?.consecutiveRateLimits ?? 0) >= persistentRateLimits;

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
    // Después de un 429 (o de una sospecha, R4), de a uno hasta una
    // respuesta aceptada: el primero hace de sonda y ningún otro queda
    // esperando dentro del limitador (cada uno pagaría otra pausa).
    while (_running <
            (_inRateLimitEpisode || _inSuspicion ? 1 : maxConcurrent) &&
        _queue.isNotEmpty) {
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
              if (_retriesAfterRateLimit(job, error) ||
                  _retriesAfterSuspicion(job, error)) {
                requeued = true;
                return;
              }
              final failure = _withReason(job, error);
              job.completer.completeError(failure, stack);
              // La sonda volvió a dar 429: los demás fallarían igual.
              if (error is RateLimitFailure && _probeFailed) {
                _failFastUntil = _rateLimit?.pausedUntil;
                _failQueued();
              }
              if (failure is NetworkFailure && _suspicionProbeFailed(error)) {
                _failSuspectedQueued(failure);
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
  /// alguien lo espera, la pausa es razonable y no hay bloqueo persistente.
  bool _retriesAfterRateLimit(_Job job, Object error) {
    if (error is! RateLimitFailure ||
        job.isAbandoned ||
        isRateLimitBlocked ||
        job.rateLimitRetries >= maxRateLimitRetries ||
        _longPause) {
      return false;
    }
    job.rateLimitRetries++;
    _queue.add(job);
    return true;
  }

  /// Si el trabajo vuelve a la cola tras una sospecha de 429 oculto (Fase
  /// R4): una sola vez, si alguien lo espera y no hay bloqueo persistente.
  bool _retriesAfterSuspicion(_Job job, Object error) {
    if (error is! NetworkFailure ||
        !error.suspectedRateLimit ||
        job.isAbandoned ||
        isRateLimitBlocked ||
        job.retriedSuspicion) {
      return false;
    }
    job.retriedSuspicion = true;
    _queue.add(job);
    return true;
  }

  /// Hay un episodio de sospecha abierto (Fase R4).
  bool get _inSuspicion => _rateLimit?.inSuspicion ?? false;

  /// Una falla de red sin sospecha con el episodio abierto: salió después
  /// de la espera (la sonda) y la recuperación no funcionó.
  bool _suspicionProbeFailed(Object error) =>
      _inSuspicion &&
      error is NetworkFailure &&
      !error.suspectedRateLimit &&
      (error.issue == NetworkIssue.possibleCors ||
          error.issue == NetworkIssue.offline);

  /// Termina sin consultar los trabajos que esperaban el reintento de una
  /// sospecha: la sonda ya volvió a fallar.
  void _failSuspectedQueued(NetworkFailure failure) {
    final waiting = [
      for (final job in _queue)
        if (job.retriedSuspicion) job,
    ];
    for (final job in waiting) {
      _queue.remove(job);
      _byKey.remove(job.key);
      job.completer.completeError(failure);
    }
  }

  /// La pausa vigente supera [maxRateLimitWait].
  bool get _longPause {
    final until = _rateLimit?.pausedUntil;
    return until != null && until.difference(_clock.now()) > maxRateLimitWait;
  }

  /// Hubo un 429 sin una respuesta aceptada después.
  bool get _inRateLimitEpisode => (_rateLimit?.consecutiveRateLimits ?? 0) > 0;

  /// Un 429 con el bloqueo ya confirmado antes de esa consulta.
  bool get _probeFailed =>
      (_rateLimit?.consecutiveRateLimits ?? 0) > persistentRateLimits;

  /// El error de un 429 que no se reintenta, con el motivo (para el
  /// mensaje: no decir «varios intentos» si hubo uno).
  ///
  /// Una falla ambigua del episodio de sospecha (la sonda o un trabajo que
  /// ya se reintentó) sale marcada: quien la recibe no sigue descargando
  /// (Fase R4).
  Object _withReason(_Job job, Object error) {
    if (error is NetworkFailure &&
        error.issue == NetworkIssue.possibleCors &&
        !error.suspectedRateLimit &&
        (job.retriedSuspicion || _inSuspicion)) {
      return error.withSuspectedRateLimit();
    }
    if (error is! RateLimitFailure || job.isAbandoned) return error;
    if (_longPause) {
      return error.withReason(
        RateLimitReason.longPause,
        retryAt: _rateLimit?.pausedUntil,
      );
    }
    if (job.rateLimitRetries >= maxRateLimitRetries) {
      return error.withReason(RateLimitReason.retriesExhausted);
    }
    if (isRateLimitBlocked) {
      return error.withReason(RateLimitReason.persistentBlock);
    }
    return error;
  }

  /// Termina los trabajos en cola (también los que esperaban un reintento)
  /// sin consultar: el bloqueo sigue después de una pausa de 240 s.
  void _failQueued() {
    final queued = [..._queue];
    _queue.clear();
    for (final job in queued) {
      _byKey.remove(job.key);
      job.completer.completeError(_persistentBlock);
    }
  }

  /// El error de un trabajo que no llegó a consultar.
  static const _persistentBlock = RateLimitFailure(
    detail: 'No se consultó: TheSportsDB sigue limitando las consultas.',
    reason: RateLimitReason.persistentBlock,
  );

  /// Consultas en pausa por HTTP 429 (o en la espera de una sospecha, R4):
  /// no empieza nada (las que empezaran esperarían en el limitador en orden
  /// de llegada) y se vuelve a mirar la cola al terminar la pausa.
  bool _waitingRateLimit() {
    final paused = _rateLimit?.pausedUntil;
    final suspected = _rateLimit?.suspectedUntil;
    final until = paused == null || (suspected?.isAfter(paused) ?? false)
        ? suspected
        : paused;
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

  /// Ya volvió a la cola por una sospecha de 429 oculto (Fase R4).
  var retriedSuspicion = false;

  /// Quienes lo esperan; `null` = sin posibilidad de cancelar.
  final owners = <CancelToken?>[];

  bool get isAbandoned =>
      owners.every((token) => token != null && token.isCancelled);
}
