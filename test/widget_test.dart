import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/app/app.dart';
import 'package:futbol_argentino/app/di/app_dependencies.dart';
import 'package:futbol_argentino/core/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late int apiCalls;

  Future<void> pumpApp(
    WidgetTester tester, {
    required Size size,
    bool enableDiagnostics = true,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final deps = AppDependencies.create(
      config: AppConfig(apiKey: '123', enableDiagnostics: enableDiagnostics),
      httpClient: MockClient((_) async {
        apiCalls++;
        return http.Response('{"events": null}', 200);
      }),
    );
    addTearDown(deps.dispose);

    await tester.pumpWidget(FutbolArgentinoApp(dependencies: deps));
    await tester.pumpAndSettle();
  }

  setUp(() => apiCalls = 0);

  testWidgets('pantalla angosta: navegación inferior con 4 secciones', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(400, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    for (final label in ['Inicio', 'Competiciones', 'Equipos', 'Favoritos']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Fútbol Argentino'), findsOneWidget);
  });

  testWidgets('tablet: riel lateral compacto', (tester) async {
    await pumpApp(tester, size: const Size(900, 800));

    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
  });

  testWidgets('escritorio: riel lateral extendido', (tester) async {
    await pumpApp(tester, size: const Size(1400, 900));

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
  });

  testWidgets('cambiar de sección muestra su pantalla', (tester) async {
    await pumpApp(tester, size: const Size(400, 800));

    await tester.tap(find.text('Competiciones'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Fixture de Primera División'), findsOneWidget);
  });

  testWidgets('el diagnóstico abre la prueba sin consultar la API', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(400, 800));

    await tester.tap(find.byTooltip('Diagnóstico de la API'));
    await tester.pumpAndSettle();

    expect(find.text('Prueba TheSportsDB'), findsOneWidget);
    expect(find.text('Consultar API'), findsOneWidget);
    expect(apiCalls, 0);
  });

  testWidgets('sin diagnóstico habilitado no aparece el acceso', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(400, 800), enableDiagnostics: false);

    expect(find.byTooltip('Diagnóstico de la API'), findsNothing);
  });
}
