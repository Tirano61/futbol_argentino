import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/accessibility.dart';
import '../../../helpers/recorded_app.dart';

/// Fase D6: «Buscar también en copas internacionales» en la app completa
/// con respuestas grabadas (Flamengo: `searchteams` y la Fecha 1 de grupos
/// de cada copa).
void main() {
  final action = find.text('Buscar también en copas internacionales');
  final onlineNotice = find.textContaining('Resultados de TheSportsDB');

  Future<void> searchFlamengo(WidgetTester tester) async {
    await openSection(tester, 'Equipos');
    await tester.enterText(find.byType(TextField).last, 'flamengo');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  Future<void> tapAction(WidgetTester tester) async {
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
  }

  for (final (width, scale) in [(360.0, 2.0), (768.0, 1.0), (1280.0, 1.0)]) {
    testWidgets('${width.toInt()} px, texto al ${(scale * 100).toInt()} %: '
        'en línea, después entre los guardados', (tester) async {
      final semantics = tester.ensureSemantics();
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final requests = <Uri>[];
      await pumpApp(tester, Size(width, 900), requests: requests);

      await searchFlamengo(tester);
      expect(find.text('Flamengo'), findsOne);
      expect(onlineNotice, findsOne);
      expect(action, findsOne);
      if (scale == 1) await expectGuidelines(tester);

      requests.clear();
      await tapAction(tester);

      expect(
        [
          for (final u in requests)
            if (u.path.endsWith('eventsround.php')) u.query,
        ],
        ['id=4501&r=1&s=2026', 'id=4724&r=1&s=2026'],
      );
      expect(find.text('Flamengo'), findsOne);
      expect(find.text('Copa Libertadores'), findsOne);
      expect(onlineNotice, findsNothing);
      expect(action, findsNothing);
      semantics.dispose();
    });
  }
}
