import 'package:futbol_argentino/core/time/clock.dart';

/// Reloj controlado para tests. [delay] avanza el reloj en lugar de esperar,
/// y registra cada espera solicitada.
class FakeClock implements Clock {
  FakeClock([DateTime? start]) : _now = start ?? DateTime.utc(2026, 10, 11, 20);

  DateTime _now;
  final delays = <Duration>[];

  @override
  DateTime now() => _now;

  void advance(Duration duration) => _now = _now.add(duration);

  Future<void> delay(Duration duration) async {
    delays.add(duration);
    advance(duration);
  }
}
