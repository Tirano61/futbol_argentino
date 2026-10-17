import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/accessibility.dart';
import '../../../helpers/recorded_app.dart';

/// La ficha de un equipo en la app completa con respuestas grabadas: sin
/// desbordes en cada ancho, con las pautas de accesibilidad y con texto al
/// 200 %.
///
/// - Boca (Fase D6): la Copa Sudamericana entre sus partidos, con su etapa
///   (la ronda del puntero se guarda; antes, en la Fase 15, iba en «Otras
///   competiciones»).
/// - Flamengo (Fase D6, equipo extranjero encontrado en línea): sin
///   partidos guardados; sus punteros del Brasileirão en «Otras
///   competiciones (información parcial)».
void main() {
  final sudamericana = find.text(
    'Copa Sudamericana · Eliminatorias · Semifinales',
  );
  final otherSection = find.text('Otras competiciones (información parcial)');

  Future<void> openTeam(WidgetTester tester, String query, String name) async {
    await openSection(tester, 'Equipos');
    await tester.enterText(find.byType(TextField).last, query);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  /// Desliza la ficha hasta que aparezca [finder] (puede haber varios: la
  /// ida y la vuelta de una serie) y deja visible el primero.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
      await tester.pump();
    }
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
  }

  /// Sale de la ficha y deja terminar la petición que ya esperaba cupo.
  Future<void> closeDetail(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Atrás'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 1));
  }

  for (final width in [360.0, 768.0, 1280.0, 1920.0]) {
    testWidgets('${width.toInt()} px: sin desbordes y con las pautas', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, Size(width, 900));

      await openTeam(tester, 'boca', 'Boca Juniors');
      await scrollTo(tester, sudamericana);
      expect(sudamericana, findsWidgets);
      expect(otherSection, findsNothing);
      await expectGuidelines(tester);
      await closeDetail(tester);

      await openTeam(tester, 'flamengo', 'Flamengo');
      await scrollTo(tester, otherSection);
      expect(find.text('Brazilian Serie A · Próximo partido'), findsOne);
      expect(find.text('Brazilian Serie A · Último partido'), findsOne);
      await expectGuidelines(tester);
      await closeDetail(tester);
      semantics.dispose();
    });
  }

  testWidgets('texto al 200 % en un teléfono: sin desbordes', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester, const Size(360, 780));

    await openTeam(tester, 'boca', 'Boca Juniors');
    await scrollTo(tester, sudamericana);
    await closeDetail(tester);

    await openTeam(tester, 'flamengo', 'Flamengo');
    await scrollTo(tester, find.text('Brazilian Serie A · Último partido'));
    await closeDetail(tester);
  });
}
