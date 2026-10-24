import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/fixture_controls.dart';
import 'package:futbol_argentino/shared/presentation/widgets/info_banner.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';
import 'package:futbol_argentino/shared/presentation/widgets/status_views.dart';
import 'package:http/http.dart' as http;

import '../helpers/real_fonts.dart';
import '../helpers/recorded_app.dart';
import '../helpers/text_layout.dart';
import '../visual/visual_helpers.dart' show useTextScale;

/// Pausa por HTTP 429 con la app completa (Fases 9, R2 y R3): mientras el
/// scheduler reintenta solo, el aviso dice a qué hora y la pantalla sigue
/// cargando; agotados los reintentos, el error ofrece «Reintentar» y nada
/// promete otro intento automático.
void main() {
  setUpAll(loadRealFonts);

  http.Response tooMany() =>
      http.Response('{"error": "Too Many Requests"}', 429);

  String recoveryText(String time) =>
      'Límite temporal de consultas de TheSportsDB. Se reintentará '
      'automáticamente a las $time.';
  const exhaustedText =
      'Demasiadas consultas: no fue posible completar la actualización. '
      'Probá de nuevo en unos minutos.';
  String lastAttemptText(String time) =>
      'TheSportsDB sigue limitando las consultas. Último intento automático '
      'a las $time.';

  Finder loading() => find.bySemanticsLabel('Cargando partidos');
  final retry = find.text('Reintentar');

  /// Ningún texto de la app promete un reintento automático.
  void expectNoAutomaticRetryPromise() =>
      expect(find.textContaining('reintentará'), findsNothing);

  testWidgets('un 429 sin datos guardados: avisa el reintento, sigue '
      'cargando y se recupera sin tocar «Reintentar»', (tester) async {
    var limited = false;
    await pumpApp(
      tester,
      const Size(360, 640),
      respond: (url) {
        // Solo la primera petición choca con el límite.
        if (limited) return null;
        limited = true;
        return tooMany();
      },
      settle: false,
    );
    // Las demás consultas esperan la pausa de 60 s.
    await tester.pump(const Duration(seconds: 1));

    // 17:00 + 60 s de pausa = 17:01 (hora argentina).
    expect(find.text(recoveryText('17:01')), findsOne);
    expect(loading(), findsOne);
    expect(find.byType(ErrorView), findsNothing);
    expect(find.textContaining('Demasiadas consultas'), findsNothing);
    expect(retry, findsNothing);

    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();

    expect(find.byType(InfoBanner), findsNothing);
    expect(find.byType(MatchCard), findsWidgets);
    expect(retry, findsNothing);
  });

  testWidgets('un 429 que se repite: la hora del aviso sigue a la pausa', (
    tester,
  ) async {
    var failures = 0;
    await pumpApp(
      tester,
      const Size(360, 640),
      respond: (url) => failures++ < 2 ? tooMany() : null,
      settle: false,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(recoveryText('17:01')), findsOne);

    // 17:01: el reintento vuelve a dar 429 y la pausa pasa a 120 s.
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(failures, 2);
    expect(find.text(recoveryText('17:03')), findsOne);
    expect(find.textContaining('17:01'), findsNothing);
    expect(loading(), findsOne);
    expect(retry, findsNothing);

    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(find.byType(InfoBanner), findsNothing);
    expect(find.byType(MatchCard), findsWidgets);
  });

  testWidgets('429 persistente en frío (Fase R3.1): 4 consultas y '
      '«Reintentar» a los 7 min (antes 8 y 24 min); el aviso pasa de '
      'reintento a último intento y a agotado', (tester) async {
    var limited = true;
    final requests = <Uri>[];
    await pumpApp(
      tester,
      const Size(360, 640),
      respond: (url) => limited ? tooMany() : null,
      requests: requests,
      settle: false,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(recoveryText('17:01')), findsOne);
    expect(loading(), findsOne);

    // Avisos de arriba, minuto a minuto, hasta que aparece «Reintentar».
    final notices = <String>[];
    var seconds = 1;
    while (retry.evaluate().isEmpty && seconds < 30 * 60) {
      await tester.pump(const Duration(seconds: 10));
      seconds += 10;
      for (final banner in tester.widgetList<InfoBanner>(
        find.byType(InfoBanner),
      )) {
        if (notices.lastOrNull != banner.text) notices.add(banner.text);
      }
    }
    await tester.pump();

    // 0, 60 y 180 s: tres 429 seguidos confirman el bloqueo; a los 420 s
    // sale una sola sonda y, al fallar, el resto termina sin consultar.
    expect(requests, hasLength(4));
    expect(seconds, lessThanOrEqualTo(8 * 60));
    expect(notices, [
      recoveryText('17:01'),
      recoveryText('17:03'),
      lastAttemptText('17:07'),
      exhaustedText,
    ]);
    expect(find.text('Demasiadas consultas'), findsOne);
    expect(
      find.textContaining('Probá de nuevo en unos minutos.'),
      findsWidgets,
    );
    expect(retry, findsOne);
    expectNoAutomaticRetryPromise();

    // Pasada la pausa, el aviso se va y «Reintentar» carga el Inicio.
    limited = false;
    await tester.pump(const Duration(minutes: 5));
    expect(find.byType(InfoBanner), findsNothing);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.byType(MatchCard), findsWidgets);
  });

  testWidgets('Retry-After de 6 min en una consulta (Fase R3.1): esa '
      'competición falla sin reintento y las demás siguen solas después de la '
      'pausa; mientras esperan, el aviso promete el reintento', (tester) async {
    var limited = false;
    await pumpApp(
      tester,
      const Size(360, 640),
      respond: (url) {
        if (limited) return null;
        limited = true;
        return http.Response(
          '{"error": "Too Many Requests"}',
          429,
          headers: {'retry-after': '360'},
        );
      },
      settle: false,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Las otras competiciones esperan la pausa: no es un fracaso global.
    expect(find.text(recoveryText('17:06')), findsOne);
    expect(find.text(exhaustedText), findsNothing);
    expect(loading(), findsOne);

    await tester.pump(const Duration(minutes: 6));
    await tester.pumpAndSettle();
    expect(find.byType(MatchCard), findsWidgets);
    expect(find.textContaining('No se pudo cargar'), findsOne);
    expect(find.byType(InfoBanner), findsWidgets);
    expect(find.textContaining('reintentará'), findsNothing);
  });

  testWidgets('con datos guardados, un 429 en «Actualizar» sigue mostrando '
      'el Inicio y no avisa «Ya está actualizado» antes de tiempo', (
    tester,
  ) async {
    var limited = false;
    await pumpApp(
      tester,
      const Size(360, 640),
      respond: (url) {
        if (!limited) return null;
        limited = false;
        return tooMany();
      },
    );
    final cards = find.byType(MatchCard).evaluate().length;
    expect(cards, greaterThan(0));

    // Más de 30 s después: el refresco manual consulta la red. El cierre de
    // la carga inicial se agenda fuera de `FakeAsync`: si no, el `HomeBloc`
    // descarta el refresco.
    await tester.pump(const Duration(minutes: 1));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    limited = true;
    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(recoveryText('17:02')), findsOne);
    expect(find.byType(MatchCard), findsNWidgets(cards));
    expect(find.textContaining('Ya está actualizado'), findsNothing);
    expect(find.textContaining('No se pudo actualizar'), findsNothing);
    expect(retry, findsNothing);

    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(find.byType(InfoBanner), findsNothing);
    expect(find.byType(MatchCard), findsWidgets);
    expect(find.textContaining('Ya está actualizado'), findsNothing);
    expect(retry, findsNothing);
  });

  // Teléfonos con el texto al 200 %: el aviso no tapa la barra ni la
  // navegación, y se puede cambiar de sección durante la pausa.
  for (final width in [360.0, 411.0]) {
    testWidgets('${width.toInt()} dp al 200 %: el aviso deja la barra y la '
        'navegación a la vista y se puede navegar', (tester) async {
      useTextScale(tester, 2);
      var limited = false;
      await pumpApp(
        tester,
        Size(width, 640),
        respond: (url) {
          if (limited) return null;
          limited = true;
          return tooMany();
        },
        settle: false,
      );
      await tester.pump(const Duration(seconds: 1));

      final banner = find.byType(InfoBanner);
      expect(banner, findsOne);
      expect(
        find.bySemanticsLabel(recoveryText('17:01')),
        findsOne,
        reason: 'los lectores de pantalla leen el texto completo',
      );
      expectWholeWords(tester, banner);
      final bannerRect = tester.getRect(banner);
      expect(bannerRect.height, lessThan(640 * 0.3));
      final appBar = tester.getRect(find.byType(AppBar).first);
      expect(appBar.top, greaterThanOrEqualTo(bannerRect.bottom));
      final navigation = tester.getRect(find.byType(NavigationBar));
      expect(navigation.bottom, 640);
      expect(loading(), findsOne);

      await tester.tap(find.text('Competiciones').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(FixtureSelectors.competitionSelectorKey), findsOne);
      expect(banner, findsOne, reason: 'la pausa sigue');
      expect(find.byType(ErrorView), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(banner, findsNothing);
      expect(tester.takeException(), isNull);
      // Deja terminar las cargas de Competiciones antes de cerrar el test.
      await tester.pump(const Duration(minutes: 2));
      await tester.pumpAndSettle();
    });
  }
}
