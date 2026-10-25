import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/fixture_controls.dart';
import 'package:futbol_argentino/shared/presentation/widgets/info_banner.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';
import 'package:futbol_argentino/shared/presentation/widgets/status_views.dart';

import '../helpers/real_fonts.dart';
import '../helpers/recorded_app.dart';
import '../helpers/text_layout.dart';
import '../visual/visual_helpers.dart' show goTo, useTextScale;

/// Fase R4 (Web): un HTTP 429 sin encabezados CORS llega como «Failed to
/// fetch», igual que un fallo de red. Poco después de una respuesta
/// aceptada es sospecha: una espera de 60 s y un reintento, con un aviso
/// que no afirma el límite. Sin respuesta reciente o sin red, el error de
/// siempre, con un texto que no inventa la causa.
void main() {
  setUpAll(loadRealFonts);

  String suspicionText(String time) =>
      'No se pudo consultar TheSportsDB. Puede deberse a la conexión o a un '
      'límite temporal. Se intentará nuevamente a las $time.';
  const neutralTitle = 'No se pudo consultar TheSportsDB';
  const neutralMessage =
      'Puede deberse a la conexión o a un límite temporal de consultas.';

  final retry = find.text('Reintentar');

  /// Nada afirma un límite confirmado ni promete un reintento.
  void expectNoConfirmedLimit() {
    expect(find.textContaining('Límite temporal de consultas'), findsNothing);
    expect(find.textContaining('Demasiadas consultas'), findsNothing);
    expect(find.textContaining('reintentará'), findsNothing);
  }

  bool isRound(Uri url) => url.path.endsWith('eventsround.php');

  testWidgets('Inicio en frío, una respuesta oculta a mitad de la carga: '
      'espera 60 s, se recupera sola y no afirma el límite', (tester) async {
    final requests = <Uri>[];
    Uri? hidden;
    await pumpApp(
      tester,
      const Size(360, 640),
      web: true,
      requests: requests,
      // La tercera consulta (ya hubo respuestas aceptadas) no se ve.
      hide: (url) {
        if (hidden != null || requests.length < 3) return false;
        hidden = url;
        return true;
      },
      settle: false,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // 17:00 + 60 s de espera.
    expect(find.text(suspicionText('17:01')), findsOne);
    expect(find.byIcon(Icons.sync_problem), findsOne);
    expectNoConfirmedLimit();
    expect(find.byType(ErrorView), findsNothing);
    expect(retry, findsNothing);
    final duringWait = requests.length;
    await tester.pump(const Duration(seconds: 30));
    expect(requests, hasLength(duringWait), reason: 'nada sale en la espera');
    expect(find.text(suspicionText('17:01')), findsOne);

    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.byType(InfoBanner), findsNothing);
    expect(find.byType(MatchCard), findsWidgets);
    expect(retry, findsNothing);
    expect(
      requests.where((u) => u == hidden),
      hasLength(2),
      reason: 'un solo reintento',
    );
  });

  for (final web in [false, true]) {
    testWidgets('${web ? 'Web' : 'Android'} sin fallas: el Inicio en frío '
        'hace sus 12 consultas, sin avisos', (tester) async {
      final requests = <Uri>[];
      await pumpApp(tester, const Size(360, 640), web: web, requests: requests);
      expect(requests, hasLength(12));
      expect(find.byType(InfoBanner), findsNothing);
      expect(find.byType(MatchCard), findsWidgets);
    });
  }

  testWidgets('Inicio en frío sin ninguna respuesta: error neutro en el '
      'acto, sin espera ni reintentos automáticos', (tester) async {
    final requests = <Uri>[];
    await pumpApp(
      tester,
      const Size(360, 640),
      web: true,
      requests: requests,
      hide: (_) => true,
      settle: false,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOne);
    expect(find.text(neutralTitle), findsOne);
    expect(find.textContaining(neutralMessage), findsOne);
    expect(find.text('Sin conexión'), findsNothing);
    expect(find.byType(InfoBanner), findsNothing);
    expect(retry, findsOne);
    expectNoConfirmedLimit();

    final sent = requests.length;
    await tester.pump(const Duration(minutes: 5));
    await tester.pumpAndSettle();
    expect(requests, hasLength(sent), reason: 'sin reintentos solos');
  });

  testWidgets('sin red según el navegador: «Sin conexión», sin sospecha '
      'aunque haya habido respuestas', (tester) async {
    var offline = false;
    final requests = <Uri>[];
    await pumpApp(
      tester,
      const Size(360, 640),
      web: true,
      requests: requests,
      browserOnline: () => !offline,
      hide: (_) => offline,
    );
    expect(find.byType(MatchCard), findsWidgets);

    // Más de 30 s después, «Actualizar» sin red.
    await tester.pump(const Duration(minutes: 1));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    offline = true;
    final sent = requests.length;
    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.textContaining('Se intentará nuevamente'), findsNothing);
    expect(find.textContaining('Sin conexión'), findsWidgets);
    expect(find.textContaining(neutralTitle), findsNothing);
    expect(find.byType(MatchCard), findsWidgets, reason: 'lo guardado');
    final failed = requests.length - sent;
    await tester.pump(const Duration(minutes: 3));
    await tester.pumpAndSettle();
    expect(requests.length - sent, failed, reason: 'sin reintentos solos');
    expectNoConfirmedLimit();
  });

  group('Tabla Anual guardada y «Actualizar» con la respuesta oculta', () {
    const coverage = 'Tabla parcial · Fechas guardadas 16 de 16';

    Future<void> openTable(WidgetTester tester) => goTo(
      tester,
      '/competiciones/4406?temporada=2026&vista=tabla&tabla=anual',
      wait: const Duration(minutes: 2),
    );

    testWidgets('una vez: la tabla sigue a la vista durante la espera y el '
        'reintento sale bien solo', (tester) async {
      var hideNext = false;
      final requests = <Uri>[];
      await pumpApp(
        tester,
        const Size(1280, 800),
        web: true,
        requests: requests,
        hide: (url) {
          if (!hideNext || !isRound(url)) return false;
          hideNext = false;
          return true;
        },
      );
      await openTable(tester);
      expect(find.textContaining(coverage), findsOne);
      final rows = find.byType(InkWell).evaluate().length;

      hideNext = true;
      requests.clear();
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final notice = find.textContaining('Se intentará nuevamente');
      expect(notice, findsOne);
      expectNoConfirmedLimit();
      expect(find.textContaining(coverage), findsOne);
      expect(find.byType(InkWell).evaluate().length, rows);
      expect(find.byType(LinearProgressIndicator), findsOne);
      expect(find.textContaining('No se pudo actualizar'), findsNothing);
      expect(find.textContaining('Ya está actualizado'), findsNothing);
      expect(requests, hasLength(1));

      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(notice, findsNothing);
      expect(find.textContaining(coverage), findsOne);
      expect(find.textContaining('No se pudo actualizar'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Reintentar'), findsNothing);
      expect(requests.first, requests[1], reason: 'reintentó la misma fecha');
    });

    testWidgets('siempre: un reintento, error neutro con «Reintentar» y la '
        'descarga no sigue', (tester) async {
      var hidden = false;
      final requests = <Uri>[];
      await pumpApp(
        tester,
        const Size(1280, 800),
        web: true,
        requests: requests,
        hide: (url) => hidden && isRound(url),
      );
      await openTable(tester);
      final rows = find.byType(InkWell).evaluate().length;

      hidden = true;
      requests.clear();
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Se intentará nuevamente'), findsOne);

      final retryButton = find.widgetWithText(TextButton, 'Reintentar');
      var seconds = 0;
      while (retryButton.evaluate().isEmpty && seconds < 10 * 60) {
        await tester.pump(const Duration(seconds: 10));
        seconds += 10;
      }
      await tester.pumpAndSettle();
      expect(seconds, lessThanOrEqualTo(70));
      expect(requests, hasLength(2), reason: 'la fecha y un reintento');
      expect(retryButton, findsOne);
      expect(find.textContaining('Se intentará nuevamente'), findsNothing);
      expectNoConfirmedLimit();
      expect(find.textContaining(neutralTitle), findsWidgets);
      expect(find.textContaining(coverage), findsOne);
      // Las filas de la tabla, más el botón «Reintentar».
      expect(find.byType(InkWell).evaluate().length, rows + 1);

      // Los minutos siguientes no sale nada solo.
      await tester.pump(const Duration(minutes: 5));
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
    });
  });

  // Teléfonos con el texto al 200 %: el aviso no tapa la barra ni la
  // navegación, y se puede cambiar de sección durante la espera.
  for (final width in [360.0, 411.0]) {
    testWidgets('${width.toInt()} dp al 200 %: el aviso de sospecha deja la '
        'barra y la navegación a la vista y se puede navegar', (tester) async {
      useTextScale(tester, 2);
      final requests = <Uri>[];
      var hidden = false;
      await pumpApp(
        tester,
        Size(width, 640),
        web: true,
        requests: requests,
        hide: (url) {
          if (hidden || requests.length < 3) return false;
          hidden = true;
          return true;
        },
        settle: false,
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      final banner = find.byType(InfoBanner);
      expect(banner, findsOne);
      expect(
        find.bySemanticsLabel(suspicionText('17:01')),
        findsOne,
        reason: 'los lectores de pantalla leen el texto completo',
      );
      expectWholeWords(tester, banner);
      final bannerRect = tester.getRect(banner);
      expect(bannerRect.height, lessThan(640 * 0.3));
      final appBar = tester.getRect(find.byType(AppBar).first);
      expect(appBar.top, greaterThanOrEqualTo(bannerRect.bottom));
      expect(tester.getRect(find.byType(NavigationBar)).bottom, 640);

      await tester.tap(find.text('Competiciones').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(FixtureSelectors.competitionSelectorKey), findsOne);
      expect(banner, findsOne, reason: 'la espera sigue');
      expect(find.byType(ErrorView), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(banner, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(minutes: 2));
      await tester.pumpAndSettle();
    });
  }
}
