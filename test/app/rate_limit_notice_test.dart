import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/app/shell/rate_limit_notice.dart';
import 'package:futbol_argentino/app/theme/app_theme.dart';
import 'package:futbol_argentino/core/network/rate_limit_status.dart';
import 'package:futbol_argentino/core/network/rate_limiter.dart';
import 'package:futbol_argentino/core/time/clock.dart';

import '../helpers/accessibility.dart';

/// Reloj del tiempo simulado de `pump` (17:00 de Argentina al empezar).
class _PumpedClock implements Clock {
  _PumpedClock(this._tester) : _origin = _tester.binding.clock.now();

  final WidgetTester _tester;
  final DateTime _origin;

  @override
  DateTime now() => DateTime.utc(
    2026,
    10,
    11,
    20,
  ).add(_tester.binding.clock.now().difference(_origin));
}

const throttleText =
    'Muchas consultas seguidas: para no pasar el límite de TheSportsDB, se '
    'sigue en menos de un minuto.';

void main() {
  late RateLimiter limiter;

  Future<void> pumpNotice(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    final clock = _PumpedClock(tester);
    // Tope de 2 por minuto para llegar enseguida a la espera.
    limiter = RateLimiter(maxRequests: 2, clock: clock);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<RateLimitStatus>.value(value: limiter),
          RepositoryProvider<Clock>.value(value: clock),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          home: const RateLimitNotice(child: Scaffold(body: Text('contenido'))),
        ),
      ),
    );
  }

  testWidgets('avisa la espera por el tope propio mientras dura', (
    tester,
  ) async {
    await pumpNotice(tester);
    var done = 0;
    for (var i = 0; i < 3; i++) {
      unawaited(limiter.acquire().then((_) => done++));
    }
    await tester.pump();

    expect(done, 2, reason: 'la tercera espera 1 min');
    expect(find.text(throttleText), findsOne);
    expect(find.text('contenido'), findsOne);

    await tester.pump(const Duration(seconds: 59));
    expect(find.text(throttleText), findsOne);

    await tester.pump(const Duration(seconds: 1));
    expect(done, 3);
    expect(find.text(throttleText), findsNothing);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('tema ${mode.name}: el aviso se lee (contraste)', (
      tester,
    ) async {
      await pumpNotice(tester, themeMode: mode);
      for (var i = 0; i < 3; i++) {
        unawaited(limiter.acquire());
      }
      await tester.pump();
      expect(find.text(throttleText), findsOne);

      await expectGuidelines(tester);
      await tester.pump(const Duration(minutes: 1));
    });
  }

  testWidgets('la pausa por 429 tiene prioridad sobre la espera por el tope', (
    tester,
  ) async {
    await pumpNotice(tester);
    for (var i = 0; i < 3; i++) {
      unawaited(limiter.acquire());
    }
    await tester.pump(const Duration(seconds: 10));
    expect(find.text(throttleText), findsOne);

    // 17:00:10 + 20 s: la pausa termina antes que la espera por el tope.
    limiter.pauseFor(const Duration(seconds: 20));
    // La pausa llega por un stream después del cuadro: otro para dibujarla.
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('pidió esperar'), findsOne);
    expect(find.text(throttleText), findsNothing);

    await tester.pump(const Duration(seconds: 20));
    expect(find.textContaining('pidió esperar'), findsNothing);
    expect(find.text(throttleText), findsOne);

    await tester.pump(const Duration(seconds: 30));
    expect(find.byIcon(Icons.hourglass_top), findsNothing);
  });
}
