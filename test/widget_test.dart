import 'package:flutter_test/flutter_test.dart';

import 'package:futbol_argentino/main.dart';

void main() {
  testWidgets('Muestra la pantalla de prueba sin consultar la API', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FutbolArgentinoApp());

    expect(find.text('Prueba TheSportsDB'), findsOneWidget);
    expect(find.text('Consultar API'), findsOneWidget);
  });
}
