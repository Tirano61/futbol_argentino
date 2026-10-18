import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/shared/presentation/widgets/info_banner.dart';
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
    await pumpApp(
      tester,
      const Size(1280, 800),
      respond: (url) => limited && url.path.endsWith('eventsround.php')
          ? http.Response('{"error": "Too Many Requests"}', 429)
          : null,
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
    await tester.tap(find.byTooltip('Actualizar'));
    // Cada 429 pausa las consultas un minuto (y se reintenta dos veces).
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(minutes: 1));
    }
    await tester.pumpAndSettle();

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
