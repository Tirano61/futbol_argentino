import 'dart:async';

import '../error/failure.dart';
import '../network/rate_limit_status.dart';
import 'cancel_token.dart';
import 'sync_scheduler.dart';

/// Si la recuperación automática de un HTTP 429 sigue en pie (Fases R3 y
/// R3.1), para que el aviso de la pausa no prometa de más ni de menos.
///
/// El `SyncScheduler` reintenta solo los trabajos que fallan por 429: un
/// `RateLimitFailure` que le llega a quien espera un trabajo es uno que dejó
/// de reintentar (agotó los intentos, la pausa es demasiado larga o
/// TheSportsDB sigue limitando).
abstract interface class RateLimitRecovery {
  /// Fin (UTC) de la pausa por 429 durante la que se abandonó un trabajo;
  /// `null` si no pasó nunca.
  DateTime? get abandonedPause;

  /// Hay trabajos en cola o en curso: siguen solos al terminar la pausa.
  bool get hasPendingWork;

  /// TheSportsDB sigue limitando (bloqueo persistente): lo pendiente tiene
  /// un último intento, de a uno.
  bool get isPersistentBlock;

  /// Avisa cada cambio de lo anterior (trabajos que llegan o terminan,
  /// abandonos).
  Stream<void> get changes;
}

/// `SyncScheduler` que informa lo pendiente y los trabajos abandonados tras
/// un 429. No cambia la cola ni los reintentos: solo mira cómo empieza y
/// termina cada pedido.
class ObservedSyncScheduler extends SyncScheduler implements RateLimitRecovery {
  ObservedSyncScheduler({
    super.clock,
    super.delay,
    required RateLimitStatus rateLimit,
  }) : _status = rateLimit,
       super(rateLimit: rateLimit);

  final RateLimitStatus _status;
  DateTime? _abandonedPause;
  final _changes = StreamController<void>.broadcast();

  @override
  DateTime? get abandonedPause => _abandonedPause;

  @override
  bool get hasPendingWork => pending > 0;

  @override
  bool get isPersistentBlock => isRateLimitBlocked;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<void> run(
    String key,
    SyncPriority priority,
    Future<void> Function() task, {
    CancelToken? cancelToken,
  }) {
    final done = super.run(key, priority, task, cancelToken: cancelToken);
    _changes.add(null);
    done.then<void>(
      (_) => _settled(),
      onError: (Object error) {
        // Quien canceló ya no espera: el scheduler tampoco reintenta un
        // trabajo que nadie espera, y eso no es agotar los intentos.
        if (error is RateLimitFailure && !(cancelToken?.isCancelled ?? false)) {
          _abandon();
        }
        _settled();
      },
    );
    return done;
  }

  /// El scheduler ya sacó el trabajo de la cola cuando avisa a quien lo
  /// espera; el aviso sale después de los demás que esperaban el trabajo.
  void _settled() => scheduleMicrotask(() => _changes.add(null));

  void _abandon() {
    final until = _status.pausedUntil;
    if (until == null || until == _abandonedPause) return;
    _abandonedPause = until;
    _changes.add(null);
  }
}
