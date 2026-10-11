import 'dart:async';

/// Prioridad de un trabajo de sincronización (§5.8).
///
/// Hito A usa solo P0 y P1; P2 (equipo) y P3 (historial) llegan después.
enum SyncPriority {
  /// P0: lo que el usuario está mirando o un refresco manual.
  visible,

  /// P1: contexto (ronda vecina, rondas actuales del Inicio).
  context,
}

/// Cola única de trabajos de una petición: deduplica por clave, atiende por
/// prioridad y en orden de llegada, y limita los trabajos simultáneos. El
/// ritmo de peticiones lo controla el `RateLimiter` del cliente.
class SyncScheduler {
  SyncScheduler({this.maxConcurrent = 2});

  final int maxConcurrent;

  final _queue = <_Job>[];
  final _byKey = <String, _Job>{};
  var _running = 0;
  var _sequence = 0;

  /// Ejecuta [task] o se suma a un trabajo con la misma [key] ya pendiente
  /// o en curso (y le sube la prioridad si todavía está en cola).
  Future<void> run(
    String key,
    SyncPriority priority,
    Future<void> Function() task,
  ) {
    final existing = _byKey[key];
    if (existing != null) {
      if (priority.index < existing.priority.index &&
          _queue.contains(existing)) {
        existing.priority = priority;
      }
      return existing.completer.future;
    }
    final job = _Job(key, priority, task, _sequence++);
    _byKey[key] = job;
    _queue.add(job);
    _pump();
    return job.completer.future;
  }

  /// Trabajos en cola o en curso (para diagnóstico y tests).
  int get pending => _byKey.length;

  void _pump() {
    while (_running < maxConcurrent && _queue.isNotEmpty) {
      _queue.sort(
        (a, b) => a.priority != b.priority
            ? a.priority.index - b.priority.index
            : a.sequence - b.sequence,
      );
      final job = _queue.removeAt(0);
      _running++;
      job
          .task()
          .then(job.completer.complete, onError: job.completer.completeError)
          .whenComplete(() {
            _running--;
            _byKey.remove(job.key);
            _pump();
          });
    }
  }
}

class _Job {
  _Job(this.key, this.priority, this.task, this.sequence);

  final String key;
  SyncPriority priority;
  final Future<void> Function() task;
  final int sequence;
  final completer = Completer<void>();
}
