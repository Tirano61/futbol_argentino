import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/app/theme/app_theme.dart';
import 'package:futbol_argentino/features/competitions/presentation/routing/fixture_route.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/view_tabs.dart';
import 'package:futbol_argentino/shared/presentation/widgets/scroll_row.dart';

import '../helpers/accessibility.dart';
import '../helpers/real_fonts.dart';

/// Hito E, Fase E7: los estados de los chips y las pestañas con el tema de
/// la app y la fuente real, en los dos temas y al 100 y al 200 %:
/// elegido, sin elegir, deshabilitado y con foco. La pauta de contraste se
/// evalúa con el chip sin elegir **después** de uno elegido en negrita (el
/// caso de «Apertura · Clausura» de E6) y con el foco en él.
void main() {
  setUpAll(loadRealFonts);

  final focus = FocusNode();
  tearDownAll(focus.dispose);

  Future<void> pumpControls(
    WidgetTester tester, {
    required Brightness brightness,
    required double width,
    required double scale,
  }) async {
    tester.view
      ..physicalSize = Size(width, 600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: brightness == Brightness.light
            ? ThemeMode.light
            : ThemeMode.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ViewTabs(
                view: CompetitionsView.table,
                views: CompetitionsView.values,
                onChanged: (_) {},
              ),
              ScrollRow(
                children: [
                  ChoiceChip(
                    label: const Text('Apertura'),
                    selected: true,
                    onSelected: (_) {},
                  ),
                  ChoiceChip(
                    label: const Text('Clausura'),
                    selected: false,
                    focusNode: focus,
                    onSelected: (_) {},
                  ),
                  const ChoiceChip(
                    label: Text('Sin datos'),
                    selected: false,
                    onSelected: null,
                  ),
                ],
              ),
              Wrap(
                children: [
                  ActionChip(
                    label: const Text('Primera Nacional'),
                    tooltip: 'Fixture de Primera Nacional',
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  RenderParagraph paragraph(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(find.text(text));

  for (final brightness in Brightness.values) {
    for (final width in [360.0, 1280.0]) {
      for (final scale in [1.0, 2.0]) {
        final theme = brightness == Brightness.light ? 'claro' : 'oscuro';
        testWidgets('${width.toInt()} px · ${(scale * 100).toInt()} % · '
            '$theme', (tester) async {
          final semantics = tester.ensureSemantics();
          await pumpControls(
            tester,
            brightness: brightness,
            width: width,
            scale: scale,
          );

          // Sin foco y con el foco en el chip sin elegir.
          await expectGuidelines(tester);
          focus.requestFocus();
          await tester.pumpAndSettle();
          expect(focus.hasFocus, isTrue);
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          focus.unfocus();
          await tester.pumpAndSettle();

          // El elegido no se distingue solo por el color: va en negrita
          // (y sin borde; el resto con el borde fino).
          expect(
            paragraph(tester, 'Apertura').text.style?.fontWeight,
            FontWeight.w700,
          );
          expect(
            paragraph(tester, 'Clausura').text.style?.fontWeight,
            isNot(FontWeight.w700),
          );
          // Cada chip de la fila empieza en un píxel entero: el texto se
          // dibuja nítido con densidad 1 (Web en un monitor común).
          for (final label in ['Apertura', 'Clausura', 'Sin datos']) {
            final left = tester
                .getTopLeft(find.widgetWithText(ChoiceChip, label))
                .dx;
            expect(left, left.roundToDouble(), reason: label);
          }

          // Deshabilitado: se anuncia así (la pauta de contraste de WCAG no
          // se aplica a controles inactivos) y se ve distinto del activo.
          expect(
            tester.getSemantics(find.widgetWithText(ChoiceChip, 'Sin datos')),
            isSemantics(
              label: 'Sin datos',
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
              hasSelectedState: true,
            ),
          );
          expect(
            paragraph(tester, 'Sin datos').text.style?.color,
            isNot(paragraph(tester, 'Clausura').text.style?.color),
          );

          // Pestañas: la elegida con su estado en la semántica.
          expect(
            tester.getSemantics(
              find.ancestor(
                of: find.text('Tabla'),
                matching: find.byType(Semantics),
              ).first,
            ),
            isSemantics(
              label: 'Tabla',
              isButton: true,
              isSelected: true,
              hasSelectedState: true,
              isInMutuallyExclusiveGroup: true,
            ),
          );
          semantics.dispose();
        });
      }
    }
  }
}
