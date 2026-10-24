import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/shared/presentation/widgets/info_banner.dart';
import 'package:futbol_argentino/shared/presentation/widgets/status_views.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../helpers/real_fonts.dart';
import '../helpers/recorded_app.dart';
import '../visual/visual_helpers.dart' show goTo, useTextScale;

/// Hito E, Fase E7: los avisos de una descarga de rondas.
/// - Tras un HTTP 429 la Tabla decía «No se pudieron consultar todas las
///   fechas (16 de 16)»: el número eran las fechas guardadas. Ahora el aviso
///   separa lo guardado, lo al día y la actualización que falló.
/// - Con texto grande, la acción de un aviso («Completar») baja debajo del
///   texto en vez de dejarlo en una columna angosta.
void main() {
  setUpAll(loadRealFonts);

  String bannerText(WidgetTester tester) => tester
      .widget<InfoBanner>(
        find.byWidgetPredicate(
          (w) => w is InfoBanner && w.text.contains('actualizar'),
        ),
      )
      .text;

  testWidgets('Tabla Anual: un 429 en el refresco manual no se informa como '
      '«16 de 16»; dice qué se muestra y que no se pudo actualizar', (
    tester,
  ) async {
    var limited = false;
    final requests = <Uri>[];
    await pumpApp(
      tester,
      const Size(1280, 800),
      respond: (url) => limited && url.path.endsWith('eventsround.php')
          ? http.Response('{"error": "Too Many Requests"}', 429)
          : null,
      requests: requests,
    );
    await goTo(
      tester,
      '/competiciones/4406?temporada=2026&vista=tabla&tabla=anual',
      wait: const Duration(minutes: 2),
    );
    expect(
      find.textContaining('Tabla parcial · Fechas guardadas 16 de 16'),
      findsOne,
    );

    limited = true;
    requests.clear();
    await tester.tap(find.byTooltip('Actualizar'));
    // La fecha en curso se intenta 3 veces (pausas de 60 y 120 s). Fase
    // R3.1: después la descarga no sigue (antes, una ronda más esperaba la
    // pausa de 240 s y «Reintentar» llegaba a los ~8 min).
    final retry = find.widgetWithText(TextButton, 'Reintentar');
    var minutes = 0;
    while (retry.evaluate().isEmpty && minutes < 15) {
      await tester.pump(const Duration(minutes: 1));
      minutes++;
    }
    expect(minutes, lessThanOrEqualTo(4));
    expect(requests, hasLength(3));
    await tester.pumpAndSettle();
    // Fase R3: agotados los reintentos, nada promete otro intento
    // automático (el aviso de arriba, si la pausa sigue, tampoco).
    expect(find.textContaining('reintentará'), findsNothing);

    final text = bannerText(tester);
    expect(text, contains('Se muestra lo guardado (16 de 16 fechas)'));
    expect(text, contains('Demasiadas consultas'));
    expect(
      text,
      anyOf(
        startsWith('No se pudo actualizar.'),
        matches(
          RegExp(
            r'^No se pudieron actualizar todas las fechas: \d+ de 16 al día\.',
          ),
        ),
      ),
    );
    expect(find.textContaining('consultar todas las fechas'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Reintentar'), findsOne);
    // La cobertura sigue diciendo lo guardado.
    expect(
      find.textContaining('Tabla parcial · Fechas guardadas 16 de 16'),
      findsOne,
    );
  });

  testWidgets('Tabla Anual: un 429 en el refresco manual se reintenta solo; '
      'mientras espera, la tabla guardada sigue a la vista y no se informa '
      'éxito ni error', (tester) async {
    var limited = false;
    await pumpApp(
      tester,
      const Size(1280, 800),
      respond: (url) {
        if (!limited || !url.path.endsWith('eventsround.php')) return null;
        limited = false;
        return http.Response('{"error": "Too Many Requests"}', 429);
      },
    );
    await goTo(
      tester,
      '/competiciones/4406?temporada=2026&vista=tabla&tabla=anual',
      wait: const Duration(minutes: 2),
    );
    const coverage = 'Tabla parcial · Fechas guardadas 16 de 16';
    expect(find.textContaining(coverage), findsOne);
    final rows = find.byType(InkWell).evaluate().length;

    limited = true;
    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // La pausa de 60 s: el aviso dice a qué hora se reintenta.
    final notice = find.textContaining('Se reintentará automáticamente');
    expect(notice, findsOne);
    expect(find.textContaining(coverage), findsOne);
    expect(find.byType(InkWell).evaluate().length, rows);
    // El refresco sigue en curso: la barra indeterminada, nunca un avance
    // terminado.
    final progress = find.byType(LinearProgressIndicator);
    expect(progress, findsOne, reason: 'la descarga sigue en curso');
    expect(find.text('Fechas al día: 16 de 16'), findsNothing);
    expect(find.textContaining('Ya está actualizado'), findsNothing);
    expect(find.textContaining('No se pudo actualizar'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Reintentar'), findsNothing);

    await tester.pump(const Duration(seconds: 30));
    expect(notice, findsOne);
    expect(progress, findsOne);

    // Termina la pausa: el reintento sale bien sin tocar nada.
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(notice, findsNothing);
    expect(progress, findsNothing);
    expect(find.textContaining(coverage), findsOne);
    expect(find.textContaining('No se pudo actualizar'), findsNothing);
    expect(find.textContaining('No se pudieron actualizar'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Reintentar'), findsNothing);
    expect(
      find.textContaining('Ya está actualizado'),
      findsNothing,
      reason: 'el reintento consultó la red',
    );
  });

  testWidgets(
    'Tabla Anual en frío (solo las fechas que guardó el Inicio): un 429 '
    'deja la descarga en curso, sin error, y la tabla se completa sola',
    (tester) async {
      var limited = false;
      await pumpApp(
        tester,
        const Size(1280, 800),
        respond: (url) {
          if (!limited || !url.path.endsWith('eventsround.php')) return null;
          limited = false;
          return http.Response('{"error": "Too Many Requests"}', 429);
        },
      );
      // El Inicio también pide rondas: el 429 recién al abrir la Tabla.
      limited = true;
      // Sin `pumpAndSettle`: con el indicador girando avanzaría el tiempo
      // más allá de la pausa.
      GoRouter.of(
        tester.element(find.byType(Scaffold).first),
      ).go('/competiciones/4406?temporada=2026&vista=tabla&tabla=anual');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Se reintentará automáticamente'), findsOne);
      // Las fechas que guardó el Inicio ya arman una tabla parcial; el resto
      // sigue descargándose (nunca «16 de 16» mientras espera).
      final running = find.textContaining(
        RegExp(r'^Fechas al día: \d+ de 16$'),
      );
      expect(running, findsOne);
      expect(find.text('Fechas al día: 16 de 16'), findsNothing);
      expect(find.byType(ErrorView), findsNothing);
      expect(find.textContaining('Demasiadas consultas'), findsNothing);
      expect(find.text('Reintentar'), findsNothing);

      await tester.pump(const Duration(seconds: 30));
      expect(running, findsOne);

      await tester.pump(const Duration(minutes: 3));
      await tester.pumpAndSettle();
      expect(running, findsNothing);
      expect(find.textContaining('Se reintentará'), findsNothing);
      expect(
        find.textContaining('Tabla parcial · Fechas guardadas 16 de 16'),
        findsOne,
      );
      expect(find.text('Reintentar'), findsNothing);
    },
  );

  // Fase R3.1: Calendario y Llaves con «Actualizar» y 429 persistente: la
  // fecha forzada se intenta 3 veces y la descarga no sigue.
  for (final (view, url, now) in [
    (
      'Calendario de Primera',
      '/competiciones/4406?temporada=2026&vista=calendario',
      null,
    ),
    (
      'Llaves de la Libertadores',
      '/competiciones/4501?temporada=2026&vista=llaves',
      continentalRecordingTime,
    ),
  ]) {
    testWidgets('$view: 429 persistente en «Actualizar»: «Reintentar» a los '
        '≤ 4 min, 3 consultas y lo guardado sigue', (tester) async {
      var limited = false;
      final requests = <Uri>[];
      await pumpApp(
        tester,
        const Size(1280, 800),
        now: now,
        respond: (url) => limited && url.path.endsWith('eventsround.php')
            ? http.Response('{"error": "Too Many Requests"}', 429)
            : null,
        requests: requests,
      );
      await goTo(tester, url, wait: const Duration(minutes: 2));
      if (view.startsWith('Calendario')) {
        // El calendario abre con lo guardado: completa la temporada.
        await tester.tap(find.widgetWithText(TextButton, 'Completar'));
        await tester.pump(const Duration(minutes: 3));
        await tester.pumpAndSettle();
      }
      // Pasan los 30 s entre refrescos.
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();

      limited = true;
      requests.clear();
      await tester.tap(find.byTooltip('Actualizar'));
      final retry = find.widgetWithText(TextButton, 'Reintentar');
      var minutes = 0;
      while (retry.evaluate().isEmpty && minutes < 15) {
        await tester.pump(const Duration(minutes: 1));
        minutes++;
      }

      expect(minutes, lessThanOrEqualTo(4));
      expect(requests, hasLength(3));
      expect(requests.map((u) => u.query).toSet(), hasLength(1));
      expect(find.textContaining('Demasiadas consultas'), findsWidgets);
      expect(find.textContaining('reintentará'), findsNothing);
      await tester.pump(const Duration(minutes: 5));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('Fase R3.1: dos pantallas a la vez con 429 persistente (el '
      'Inicio esperando y se abre la Tabla): terminan juntas a los 7 min y '
      'el aviso coincide con lo que queda pendiente', (tester) async {
    final requests = <Uri>[];
    await pumpApp(
      tester,
      const Size(1280, 800),
      respond: (url) => http.Response('{"error": "Too Many Requests"}', 429),
      requests: requests,
      settle: false,
    );
    await tester.pump(const Duration(seconds: 1));
    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).go('/competiciones/4406?temporada=2026&vista=tabla&tabla=anual');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final notices = <String>[];
    var seconds = 2;
    final retry = find.text('Reintentar');
    while (retry.evaluate().isEmpty && seconds < 30 * 60) {
      await tester.pump(const Duration(seconds: 10));
      seconds += 10;
      for (final banner in tester.widgetList<InfoBanner>(
        find.byType(InfoBanner),
      )) {
        if (banner.text.contains('TheSportsDB') &&
            notices.lastOrNull != banner.text) {
          notices.add(banner.text);
        }
      }
    }
    // La sonda falló a los 420 s: la Tabla y lo que quedaba del Inicio
    // terminan juntos, sin reintentos encadenados.
    expect(seconds, lessThanOrEqualTo(8 * 60));
    expect(requests, hasLength(4));
    expect(notices, [
      startsWith('Límite temporal de consultas de TheSportsDB. Se reintentará'),
      startsWith('Límite temporal de consultas de TheSportsDB. Se reintentará'),
      'TheSportsDB sigue limitando las consultas. Último intento automático '
          'a las 17:07.',
    ]);
    // El fixture de Competiciones, sin punteros, pide después la fecha 1 y
    // precarga la 2: con la sonda ya fallida, fallan en el acto (antes,
    // cada uno esperaba otra pausa de 240 s). Ya no queda nada pendiente.
    await tester.pump();
    await tester.pump();
    final banners = tester
        .widgetList<InfoBanner>(find.byType(InfoBanner))
        .map((b) => b.text);
    expect(banners, contains(startsWith('Demasiadas consultas:')));
    expect(find.textContaining('intento automático'), findsNothing);
    expect(find.textContaining('reintentará'), findsNothing);
    await tester.pump(const Duration(minutes: 4));
    expect(requests, hasLength(4));

    // El Inicio también terminó con su error.
    await tester.tap(find.text('Inicio').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Reintentar'), findsWidgets);
    await tester.pump(const Duration(minutes: 5));
    await tester.pumpAndSettle();
  });

  group('aviso «Completar» del Calendario', () {
    final banner = find.byWidgetPredicate(
      (w) => w is InfoBanner && w.text.contains('fechas'),
    );
    final message = find.descendant(
      of: banner,
      matching: find.textContaining('fechas'),
    );
    final action = find.descendant(
      of: banner,
      matching: find.widgetWithText(TextButton, 'Completar'),
    );

    Future<void> openCalendar(
      WidgetTester tester,
      double width,
      double scale,
    ) async {
      if (scale != 1) useTextScale(tester, scale);
      await pumpApp(tester, Size(width, 900));
      await goTo(tester, '/competiciones/4616?temporada=2026&vista=calendario');
      expect(banner, findsOne);
    }

    for (final (width, scale) in [(360.0, 1.0), (768.0, 2.0)]) {
      testWidgets('${width.toInt()} px al ${(scale * 100).toInt()} %: la '
          'acción al lado del texto', (tester) async {
        await openCalendar(tester, width, scale);
        final text = tester.getRect(message);
        final button = tester.getRect(action);
        expect(button.left, greaterThanOrEqualTo(text.right));
        expect(button.center.dy, lessThan(text.bottom));
        expect(button.center.dy, greaterThan(text.top));
      });
    }

    testWidgets('360 px al 200 %: la acción debajo y el texto a lo ancho', (
      tester,
    ) async {
      await openCalendar(tester, 360, 2);
      final box = tester.getRect(banner);
      final text = tester.getRect(message);
      final button = tester.getRect(action);
      expect(button.top, greaterThanOrEqualTo(text.bottom));
      expect(button.right, moreOrLessEquals(box.right, epsilon: 4));
      // El texto ocupa el ancho del aviso menos el ícono y los márgenes.
      expect(text.width, greaterThan(box.width * 0.75));
      expect(tester.takeException(), isNull);
    });
  });
}
