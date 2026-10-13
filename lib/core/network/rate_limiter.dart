import 'dart:async';
import 'dart:collection';

import '../time/clock.dart';
import 'rate_limit_status.dart';

typedef Delay = Future<void> Function(Duration duration);

Future<void> _realDelay(Duration duration) => Future<void>.delayed(duration);

/// Limita las peticiones a [maxRequests] por [window] (ventana deslizante) y
/// las atiende en orden de llegada. Tras un HTTP 429 se pausa todo con
/// [pauseFor]. Las esperas por el tope de [throttleNoticeThreshold] o más
/// se informan en [throttles].
class RateLimiter implements RateLimitStatus {
  RateLimiter({
    required this.maxRequests,
    this.window = const Duration(minutes: 1),
    Clock clock = const SystemClock(),
    Delay delay = _realDelay,
  }) : _clock = clock,
       _delay = delay;

  /// Las esperas por el tope más cortas no se avisan (el aviso apenas se
  /// vería).
  static const throttleNoticeThreshold = Duration(seconds: 3);

  final int maxRequests;
  final Duration window;
  final Clock _clock;
  final Delay _delay;

  final _sentAt = Queue<DateTime>();
  DateTime? _pausedUntil;
  Future<void> _tail = Future<void>.value();
  final _pauses = StreamController<DateTime>.broadcast();
  DateTime? _throttledUntil;
  final _throttles = StreamController<DateTime>.broadcast();

  @override
  DateTime? get pausedUntil {
    final until = _pausedUntil;
    return until != null && _clock.now().isBefore(until) ? until : null;
  }

  @override
  Stream<DateTime> get pauses => _pauses.stream;

  @override
  DateTime? get throttledUntil {
    final until = _throttledUntil;
    return until != null && _clock.now().isBefore(until) ? until : null;
  }

  @override
  Stream<DateTime> get throttles => _throttles.stream;

  /// Espera hasta que haya cupo y lo reserva.
  Future<void> acquire() {
    final turn = _tail.then((_) => _waitForSlot());
    _tail = turn;
    return turn;
  }

  /// Bloquea nuevas peticiones durante [duration] (p. ej. 60 s tras un 429).
  void pauseFor(Duration duration) {
    final until = _clock.now().add(duration);
    final current = _pausedUntil;
    if (current == null || until.isAfter(current)) {
      _pausedUntil = until;
      _pauses.add(until);
    }
  }

  Future<void> _waitForSlot() async {
    while (true) {
      final now = _clock.now();
      while (_sentAt.isNotEmpty && !now.isBefore(_sentAt.first.add(window))) {
        _sentAt.removeFirst();
      }

      final pausedUntil = _pausedUntil;
      if (pausedUntil != null && now.isBefore(pausedUntil)) {
        await _delay(pausedUntil.difference(now));
        continue;
      }

      if (_sentAt.length < maxRequests) {
        _sentAt.addLast(now);
        return;
      }
      final wait = _sentAt.first.add(window).difference(now);
      if (wait >= throttleNoticeThreshold) {
        final until = now.add(wait);
        _throttledUntil = until;
        _throttles.add(until);
      }
      await _delay(wait);
    }
  }
}
