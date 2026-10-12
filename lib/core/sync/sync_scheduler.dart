import 'dart:async';
import 'dart:collection';

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
class SyncScheduler {
  SyncScheduler({
    this.maxConcurrent = 2,
    this.backgroundPerWindow = 10,
    this.window = const Duration(minutes: 1),
    Clock clock = const SystemClock(),
    Delay delay = _realDelay,
  }) : _clock = clock,
       _delay = delay;

  final int maxConcurrent;
  final int backgroundPerWindow;
  final Duration window;
  final Clock _clock;
  final Delay _delay;

  static const maxBackgroundConcurrent = 1;

  final _queue = <_Job>[];
  final _byKey = <String, _Job>{};
  final _backgroundStarts = Queue<DateTime>();
  var _running = 0;
  var _runningBackground = 0;
  var _sequence = 0;
  var _paused = false;
  var _wakeScheduled = false;

  /// Ejecuta [task] o se suma a un trabajo con la misma [key] ya pendiente
  /// o en curso (y le sube la prioridad si todavía está en cola).
  ///
  /// Si [cancelToken] se cancela antes de que el trabajo empiece y nadie
  /// más lo espera, el trabajo se descarta y el futuro falla con
  /// [SyncCancelled]. Un trabajo en curso no se interrumpe.
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
      job
          .task()
          .then(job.completer.complete, onError: job.completer.completeError)
          .whenComplete(() {
            _running--;
            if (background) _runningBackground--;
            _byKey.remove(job.key);
            _pump();
          });
    }
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

  /// Quienes lo esperan; `null` = sin posibilidad de cancelar.
  final owners = <CancelToken?>[];

  bool get isAbandoned =>
      owners.every((token) => token != null && token.isCancelled);
}
