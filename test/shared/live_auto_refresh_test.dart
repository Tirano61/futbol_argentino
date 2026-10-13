import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/cache/cache_class.dart';
import 'package:futbol_argentino/shared/presentation/widgets/live_auto_refresh.dart';

void main() {
  final interval = LiveAutoRefresh.interval;

  /// [hasLive] y [visible] se pueden cambiar durante el test.
  late bool hasLive;
  late int ticks;

  setUp(() {
    hasLive = true;
    ticks = 0;
  });

  Widget app({bool visible = true}) => TickerMode(
    enabled: visible,
    child: LiveAutoRefresh(
      hasLiveMatches: () => hasLive,
      onTick: () => ticks++,
      child: const SizedBox(),
    ),
  );

  test('el intervalo deja vencer la vigencia live (2 min)', () {
    expect(interval, greaterThan(CacheClass.live.ttl));
    expect(
      interval,
      lessThan(CacheClass.live.ttl + const Duration(seconds: 30)),
    );
  });

  testWidgets('con partidos en vivo: un aviso por intervalo', (tester) async {
    await tester.pumpWidget(app());
    expect(ticks, 0, reason: 'al abrir no se repite la carga inicial');

    await tester.pump(interval - const Duration(seconds: 1));
    expect(ticks, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(ticks, 1);
    await tester.pump(interval);
    expect(ticks, 2);
  });

  testWidgets('sin partidos en vivo: nada; cuando empieza uno, sí', (
    tester,
  ) async {
    hasLive = false;
    await tester.pumpWidget(app());
    await tester.pump(interval * 3);
    expect(ticks, 0);

    hasLive = true;
    await tester.pump(interval);
    expect(ticks, 1);
  });

  testWidgets('oculta (otra sección): nada; al volver se pone al día', (
    tester,
  ) async {
    await tester.pumpWidget(app(visible: false));
    await tester.pump(interval * 3);
    expect(ticks, 0);

    await tester.pumpWidget(app());
    expect(ticks, 1);
    await tester.pump(interval);
    expect(ticks, 2);

    await tester.pumpWidget(app(visible: false));
    await tester.pump(interval * 3);
    expect(ticks, 2);
  });

  testWidgets('app en segundo plano: nada; al volver se pone al día', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump(interval * 3);
    expect(ticks, 0);

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    expect(ticks, 1);
    await tester.pump(interval);
    expect(ticks, 2);
  });

  testWidgets('al cerrar la pantalla se cancela', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpWidget(const SizedBox());
    await tester.pump(interval * 3);
    expect(ticks, 0);
  });
}
