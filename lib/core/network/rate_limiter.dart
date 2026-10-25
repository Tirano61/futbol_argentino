import 'dart:async';
import 'dart:collection';
import 'dart:math';

import '../time/clock.dart';
import 'rate_limit_status.dart';

typedef Delay = Future<void> Function(Duration duration);

Future<void> _realDelay(Duration duration) => Future<void>.delayed(duration);

/// Limita las peticiones a [maxRequests] por [window] (ventana deslizante) y
/// las atiende en orden de llegada. Tras un HTTP 429 ([rateLimited]) se
/// pausa todo y, durante la ventana que sigue a la pausa, las peticiones
/// salen de a una cada [cautiousGap] (sin ráfaga al reanudar). Las esperas
/// por el tope de [throttleNoticeThreshold] o más se informan en
/// [throttles].
///
/// Fase R4 (Web): una falla de red ambigua poco después de una respuesta
/// aceptada abre una espera por sospecha ([suspectRateLimit]), aparte de la
/// pausa por 429: no escala las pausas ni cuenta como 429 seguido.
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

  /// Pausas tras HTTP 429 seguidos sin `Retry-After` (la última se repite):
  /// TheSportsDB documenta «esperar 1 minuto», pero se vieron bloqueos de
  /// ~70 s y ~2 min.
  static const rateLimitPauses = [
    Duration(seconds: 60),
    Duration(seconds: 120),
    Duration(seconds: 240),
  ];

  /// Límites a la espera que pide un `Retry-After`: un valor absurdo no
  /// deja la app sin consultas.
  static const minRetryAfter = Duration(seconds: 1);
  static const maxRetryAfter = Duration(minutes: 10);

  /// Una falla de red ambigua es sospecha de 429 oculto solo si hubo una
  /// respuesta aceptada en este lapso antes de enviarla.
  static const suspicionLookback = Duration(minutes: 2);

  /// Espera por sospecha: fija (el primer escalón de [rateLimitPauses], el
  /// «esperar 1 minuto» que documenta TheSportsDB), una por episodio.
  static const suspicionPause = Duration(seconds: 60);

  final int maxRequests;
  final Duration window;
  final Clock _clock;
  final Delay _delay;

  final _sentAt = Queue<DateTime>();
  DateTime? _lastSentAt;
  DateTime? _pausedUntil;
  Future<void> _tail = Future<void>.value();
  final _pauses = StreamController<DateTime>.broadcast();
  DateTime? _throttledUntil;
  final _throttles = StreamController<DateTime>.broadcast();

  /// Inicio de la última pausa por 429 y cuántos 429 seguidos hubo (sin
  /// una respuesta aceptada en el medio).
  DateTime? _rateLimitedAt;
  var _strikes = 0;

  /// 429 seguidos del episodio (Fase R3.1). Como [_strikes], pero un 429 de
  /// una consulta enviada más de una ventana después del fin de la pausa
  /// anterior empieza otro episodio. No cambia las pausas.
  var _streak = 0;

  /// Hasta cuándo las peticiones salen espaciadas (la ventana que sigue a
  /// una pausa).
  DateTime? _cautiousUntil;

  /// Hora de la última respuesta aceptada.
  DateTime? _lastAcceptedAt;

  /// Episodio de sospecha (Fase R4): inicio y fin de su espera, y si ya
  /// falló una consulta enviada después (el reintento): hasta una respuesta
  /// aceptada no hay otra sospecha.
  DateTime? _suspectedAt;
  DateTime? _suspectedUntil;
  var _suspicionSpent = false;
  final _suspicions = StreamController<DateTime>.broadcast();

  /// Separación entre peticiones en el modo prudente: el mismo tope,
  /// repartido en la ventana.
  Duration get cautiousGap => window ~/ maxRequests;

  @override
  DateTime? get pausedUntil {
    final until = _pausedUntil;
    return until != null && _clock.now().isBefore(until) ? until : null;
  }

  @override
  Stream<DateTime> get pauses => _pauses.stream;

  @override
  int get consecutiveRateLimits {
    final until = _pausedUntil;
    if (until == null || !_clock.now().isBefore(until.add(window))) return 0;
    return _streak;
  }

  @override
  DateTime? get throttledUntil {
    final until = _throttledUntil;
    return until != null && _clock.now().isBefore(until) ? until : null;
  }

  @override
  Stream<DateTime> get throttles => _throttles.stream;

  @override
  DateTime? get suspectedUntil {
    final until = _suspectedUntil;
    return until != null && _clock.now().isBefore(until) ? until : null;
  }

  @override
  Stream<DateTime> get suspicions => _suspicions.stream;

  @override
  bool get inSuspicion => _suspectedAt != null;

  /// Espera hasta que haya cupo, lo reserva y devuelve la hora del turno
  /// (la de envío, para [rateLimited] y [recordAccepted]).
  Future<DateTime> acquire() {
    final turn = _tail.then((_) => _waitForSlot());
    _tail = turn;
    return turn;
  }

  /// Bloquea nuevas peticiones durante [duration]. Una pausa más corta no
  /// acorta la vigente. Al terminar, empieza el modo prudente.
  void pauseFor(Duration duration) {
    final until = _clock.now().add(duration);
    final current = _pausedUntil;
    if (current == null || until.isAfter(current)) {
      _pausedUntil = until;
      _cautiousUntil = until.add(window);
      _pauses.add(until);
    }
  }

  /// HTTP 429 de la petición enviada en [sentAt]: pausa lo que pide
  /// [retryAfter] (acotado) o, sin él, la espera de [rateLimitPauses] según
  /// los 429 seguidos. Un 429 de una petición enviada antes de la pausa
  /// vigente (salieron juntas) es la misma señal: no la alarga ni la
  /// escala. Devuelve cuánto falta para reanudar.
  Duration rateLimited({required DateTime sentAt, Duration? retryAfter}) {
    final pauseStart = _rateLimitedAt;
    final sameSignal = pauseStart != null && sentAt.isBefore(pauseStart);
    if (!sameSignal) {
      _strikes++;
      final previousEnd = _pausedUntil;
      if (previousEnd != null && sentAt.isAfter(previousEnd.add(window))) {
        _streak = 0;
      }
      _streak++;
      _rateLimitedAt = _clock.now();
    }
    if (retryAfter != null) {
      pauseFor(_clampRetryAfter(retryAfter));
    } else if (!sameSignal) {
      pauseFor(rateLimitPauses[min(_strikes, rateLimitPauses.length) - 1]);
    }
    return pausedUntil?.difference(_clock.now()) ?? Duration.zero;
  }

  /// El servidor aceptó la petición enviada en [sentAt]: si salió después
  /// de la última pausa por 429, la próxima vuelve a la primera espera.
  void recordAccepted(DateTime sentAt) {
    _lastAcceptedAt = _clock.now();
    final pauseStart = _rateLimitedAt;
    if (pauseStart == null || !sentAt.isBefore(pauseStart)) {
      _strikes = 0;
      _streak = 0;
    }
    final suspectedAt = _suspectedAt;
    if (suspectedAt != null && sentAt.isAfter(suspectedAt)) {
      _suspectedAt = null;
      _suspicionSpent = false;
    }
  }

  /// Falla de red ambigua (Web, el navegador no dice la causa) de la
  /// petición enviada en [sentAt]: si puede ser un HTTP 429 oculto por
  /// CORS, abre una espera de [suspicionPause] y devuelve `true`.
  ///
  /// Es sospecha si hubo una respuesta aceptada en los [suspicionLookback]
  /// anteriores al envío y el episodio no gastó su espera. Una petición
  /// enviada hasta el inicio de la espera vigente (salieron juntas) es la
  /// misma señal: no la alarga. Una enviada después (el reintento) que
  /// vuelve a fallar gasta el episodio: no hay otra sospecha hasta una
  /// respuesta aceptada. No toca la pausa por 429 ni los 429 seguidos.
  bool suspectRateLimit({required DateTime sentAt}) {
    if (_suspicionSpent) return false;
    final suspectedAt = _suspectedAt;
    if (suspectedAt != null) {
      // En Web la hora tiene milisegundos: la misma hora es la misma señal
      // (el reintento sale recién al terminar la espera).
      if (!sentAt.isAfter(suspectedAt)) return true;
      _suspicionSpent = true;
      return false;
    }
    final accepted = _lastAcceptedAt;
    if (accepted == null || sentAt.difference(accepted) > suspicionLookback) {
      return false;
    }
    final now = _clock.now();
    final until = now.add(suspicionPause);
    _suspectedAt = now;
    _suspectedUntil = until;
    final cautious = until.add(window);
    final current = _cautiousUntil;
    if (current == null || cautious.isAfter(current)) _cautiousUntil = cautious;
    _suspicions.add(until);
    return true;
  }

  static Duration _clampRetryAfter(Duration value) => value < minRetryAfter
      ? minRetryAfter
      : value > maxRetryAfter
      ? maxRetryAfter
      : value;

  Future<DateTime> _waitForSlot() async {
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
      final suspectedUntil = _suspectedUntil;
      if (suspectedUntil != null && now.isBefore(suspectedUntil)) {
        await _delay(suspectedUntil.difference(now));
        continue;
      }

      // Los turnos se reservan de a uno (cola de [acquire]): las que
      // esperaban la pausa salen separadas, no todas juntas.
      final cautiousUntil = _cautiousUntil;
      final last = _lastSentAt;
      if (cautiousUntil != null &&
          last != null &&
          now.isBefore(cautiousUntil)) {
        final next = last.add(cautiousGap);
        if (now.isBefore(next)) {
          await _delay(next.difference(now));
          continue;
        }
      }

      if (_sentAt.length < maxRequests) {
        _sentAt.addLast(now);
        _lastSentAt = now;
        return now;
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
