import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/app/shell/adaptive_shell.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/fixture_controls.dart';
import 'package:go_router/go_router.dart';

import '../helpers/accessibility.dart';
import '../helpers/recorded_app.dart';
import 'prototypes/competition_header_prototype.dart';
import 'prototypes/proposed_theme.dart';
import 'visual_helpers.dart';

/// E1, decisión E-D8: prototipo de la cabecera de Competiciones con el
/// selector en el título, dentro del `AdaptiveShell` real, en los anchos de
/// la matriz y con texto al 200 %. Las imágenes van a `goldens/prototipo_*`
/// (ver `docs/HITO_E.md`, §17.1).
void main() {
  setUpAll(loadVisualFonts);

  Future<void> pumpPrototype(
    WidgetTester tester,
    Size size, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
    CompetitionDefinition initial = CompetitionCatalog.copaLibertadores,
    bool detailPanel = false,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (textScale != 1) useTextScale(tester, textScale);

    Widget placeholder(String text) =>
        Scaffold(body: Center(child: Text(text)));
    final router = GoRouter(
      initialLocation: '/competiciones',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              AdaptiveShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, _) => placeholder('Pantalla de Inicio'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/competiciones',
                  builder: (_, _) => CompetitionHeaderPrototype(
                    initial: initial,
                    detailPanel: detailPanel,
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/equipos',
                  builder: (_, _) => placeholder('Pantalla de Equipos'),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/favoritos',
                  builder: (_, _) => placeholder('Pantalla de Favoritos'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: ProposedTheme.light,
        darkTheme: ProposedTheme.dark,
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        locale: const Locale('es', 'AR'),
        supportedLocales: const [Locale('es', 'AR'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Alto de los controles debajo de la AppBar (niveles 2 y 3).
  double headerHeight(WidgetTester tester) {
    final barBottom = tester.getBottomLeft(find.byType(AppBar).first).dy;
    final contentTop = tester
        .getTopLeft(find.byKey(CompetitionHeaderPrototype.contentKey))
        .dy;
    return contentTop - barBottom;
  }

  bool seasonInBar(WidgetTester tester) => find
      .descendant(
        of: find.byType(AppBar),
        matching: find.byKey(CompetitionHeaderPrototype.seasonKey),
      )
      .evaluate()
      .isNotEmpty;

  Finder selector() => find.byKey(CompetitionHeaderPrototype.selectorKey);

  Future<void> capture(WidgetTester tester, String name) =>
      expectScreen(tester, 'prototipo_$name');

  testWidgets('referencia: alto de los controles del diseño actual a 360', (
    tester,
  ) async {
    // La misma pantalla en la app real (Libertadores, eliminatorias).
    await pumpApp(tester, VisualSizes.phone, now: continentalRecordingTime);
    await goTo(tester, '/competiciones/4501?temporada=2026&fase=eliminatorias');
    final barBottom = tester.getBottomLeft(find.byType(AppBar).first).dy;
    final navigatorBottom = tester
        .getBottomLeft(find.byType(StageNavigator))
        .dy;
    final height = navigatorBottom - barBottom;
    // ignore: avoid_print
    print('E1 · controles del diseño actual a 360: ${height.round()} px');
    expect(height, greaterThan(200));
  });

  group('teléfono 360', () {
    for (final brightness in Brightness.values) {
      final theme = brightness == Brightness.light ? 'claro' : 'oscuro';
      testWidgets('Libertadores · $theme: ≤ 200 px de controles', (
        tester,
      ) async {
        await withRealShadows(() async {
          await pumpPrototype(
            tester,
            VisualSizes.phone,
            brightness: brightness,
          );
          final height = headerHeight(tester);
          // ignore: avoid_print
          print('E1 · prototipo 360 ($theme): ${height.round()} px');
          expect(height, lessThanOrEqualTo(200));
          expect(seasonInBar(tester), isTrue);
          await expectGuidelines(tester);
          await capture(tester, '360_$theme');
        });
      });
    }

    testWidgets('la hoja agrupada por categoría y el cambio de competición', (
      tester,
    ) async {
      await withRealShadows(() async {
        await pumpPrototype(tester, VisualSizes.phone);
        await tester.tap(selector());
        await tester.pumpAndSettle();
        for (final category in CompetitionCategory.values) {
          expect(find.text(category.label), findsWidgets);
        }
        await capture(tester, '360_hoja_claro');

        await tester.tap(find.widgetWithText(ListTile, 'Copa Sudamericana'));
        await tester.pumpAndSettle();
        // A 360 entra el nombre corto junto a la temporada.
        expect(
          find.descendant(of: selector(), matching: find.text('Sudamericana')),
          findsOne,
        );
      });
    });

    testWidgets('nombre largo: Primera B Metropolitana', (tester) async {
      await withRealShadows(() async {
        await pumpPrototype(
          tester,
          VisualSizes.phone,
          initial: CompetitionCatalog.primeraBMetropolitana,
        );
        await expectGuidelines(tester);
        await capture(tester, '360_nombre_largo_claro');
      });
    });

    testWidgets('texto al 200 %: la temporada baja al nivel 3, sin desbordes', (
      tester,
    ) async {
      await withRealShadows(() async {
        await pumpPrototype(tester, VisualSizes.phone, textScale: 2);
        expect(seasonInBar(tester), isFalse);
        expect(find.byKey(CompetitionHeaderPrototype.seasonKey), findsOne);
        // ignore: avoid_print
        print(
          'E1 · prototipo 360 al 200 %: ${headerHeight(tester).round()} px',
        );
        await expectGuidelines(tester);
        await capture(tester, '360_200_claro');
      });
    });

    testWidgets('la navegación inferior del shell sigue funcionando', (
      tester,
    ) async {
      await pumpPrototype(tester, VisualSizes.phone);
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla de Inicio'), findsOne);
      await tester.tap(find.text('Competiciones'));
      await tester.pumpAndSettle();
      expect(selector(), findsOne);
    });
  });

  group('tablet vertical 800', () {
    const size = Size(800, 1280);
    for (final brightness in Brightness.values) {
      final theme = brightness == Brightness.light ? 'claro' : 'oscuro';
      testWidgets('riel + cabecera · $theme', (tester) async {
        await withRealShadows(() async {
          await pumpPrototype(tester, size, brightness: brightness);
          expect(seasonInBar(tester), isTrue);
          await expectGuidelines(tester);
          await capture(tester, '800_$theme');
        });
      });
    }

    testWidgets('el menú agrupado por categoría', (tester) async {
      await withRealShadows(() async {
        await pumpPrototype(tester, size);
        await tester.tap(selector());
        await tester.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNWidgets(7));
        await capture(tester, '800_menu_claro');

        await tester.tap(
          find.widgetWithText(MenuItemButton, 'Primera Nacional'),
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: selector(),
            matching: find.text('Primera Nacional'),
          ),
          findsOne,
        );
      });
    });
  });

  group('tablet horizontal 1280 con panel de detalle', () {
    for (final brightness in Brightness.values) {
      final theme = brightness == Brightness.light ? 'claro' : 'oscuro';
      testWidgets('riel extendido + buscador + panel · $theme', (tester) async {
        await withRealShadows(() async {
          await pumpPrototype(
            tester,
            VisualSizes.tabletLandscape,
            brightness: brightness,
            detailPanel: true,
          );
          // El buscador de la barra (escritorio) convive con el selector.
          expect(find.widgetWithText(TextField, 'Buscar equipo'), findsOne);
          await expectGuidelines(tester);
          await capture(tester, '1280_panel_$theme');
        });
      });
    }

    testWidgets('menú abierto', (tester) async {
      await withRealShadows(() async {
        await pumpPrototype(
          tester,
          VisualSizes.tabletLandscape,
          detailPanel: true,
        );
        await tester.tap(selector());
        await tester.pumpAndSettle();
        await capture(tester, '1280_panel_menu_claro');
      });
    });

    testWidgets('texto al 200 %', (tester) async {
      await withRealShadows(() async {
        await pumpPrototype(
          tester,
          VisualSizes.tabletLandscape,
          textScale: 2,
          detailPanel: true,
        );
        await expectGuidelines(tester);
        await capture(tester, '1280_panel_200_claro');
      });
    });
  });

  testWidgets('escritorio 1920 con panel', (tester) async {
    await withRealShadows(() async {
      await pumpPrototype(tester, VisualSizes.desktop, detailPanel: true);
      expect(seasonInBar(tester), isTrue);
      await expectGuidelines(tester);
      await capture(tester, '1920_panel_claro');
    });
  });

  test('el selector mantiene la clave que usan los tests', () {
    expect(
      CompetitionHeaderPrototype.selectorKey,
      FixtureSelectors.competitionSelectorKey,
    );
  });
}
