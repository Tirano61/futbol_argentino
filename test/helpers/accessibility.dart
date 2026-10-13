import 'package:flutter_test/flutter_test.dart';

/// Pautas básicas de accesibilidad de Flutter: objetivos táctiles de al
/// menos 48 px, controles con nombre y contraste de texto.
Future<void> expectGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}
