import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:futbol_argentino/features/favorites/domain/entities/favorite_team.dart';
import 'package:http/http.dart' as http;
import 'package:sembast/sembast.dart' show Database;

import 'package:futbol_argentino/features/competitions/presentation/widgets/fixture_controls.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';

import '../helpers/fake_teams.dart';
import '../helpers/recorded_app.dart';
import 'visual_helpers.dart';

/// Capturas de referencia del Hito E (§14 de `docs/HITO_E.md`): la app
/// completa con los datos grabados, en los anchos y temas de la matriz.
///
/// En E1 las imágenes son el diseño **anterior** al rediseño («antes»).
/// Cada fase que cambie una pantalla las hace fallar a propósito; se
/// regeneran con `flutter test --update-goldens test/visual` solo después
/// de revisar las diferencias. Los escudos salen como iniciales (los tests
/// no tienen red).
void main() {
  setUpAll(loadVisualFonts);

  final scenes = <_Scene>[
    _Scene('inicio', (tester) async {}),
    // «Tus equipos» con un favorito (Fase E3).
    _Scene('inicio_favorito', (tester) async {}, seed: _saveBoca),
    _Scene(
      'fixture_primera',
      (tester) => goTo(
        tester,
        '/competiciones/4406?temporada=2026&fase=clausura&ronda=12',
      ),
    ),
    _Scene(
      'fixture_libertadores_series',
      (tester) =>
          goTo(tester, '/competiciones/4501?temporada=2026&fase=eliminatorias'),
      continental: true,
    ),
    _Scene(
      'tabla_anual',
      (tester) => goTo(
        tester,
        '/competiciones/4406?temporada=2026&vista=tabla&tabla=anual',
        wait: const Duration(minutes: 2),
      ),
    ),
    _Scene(
      'tabla_zona',
      (tester) => goTo(
        tester,
        '/competiciones/4406?temporada=2026&vista=tabla&tabla=clausura-a',
        wait: const Duration(minutes: 2),
      ),
    ),
    _Scene(
      'tabla_nacional',
      (tester) => goTo(
        tester,
        '/competiciones/4616?temporada=2026&vista=tabla&tabla=zona-a',
        wait: const Duration(minutes: 4),
      ),
    ),
    _Scene(
      'tabla_grupo_libertadores',
      (tester) => goTo(
        tester,
        '/competiciones/4501?temporada=2026&vista=tabla&tabla=grupo-a',
        wait: const Duration(minutes: 1),
      ),
      continental: true,
    ),
    // Fase E5: Boca como favorito en su zona (fila resaltada y estrella).
    _Scene(
      'tabla_favorito',
      (tester) => goTo(
        tester,
        '/competiciones/4406?temporada=2026&vista=tabla&tabla=apertura-a',
        wait: const Duration(minutes: 2),
      ),
      seed: _saveBoca,
    ),
    _Scene(
      'calendario',
      (tester) => goTo(
        tester,
        '/competiciones/4406?temporada=2026&vista=calendario&mes=2026-10',
      ),
    ),
    _Scene(
      'llaves_primera',
      (tester) => goTo(
        tester,
        '/competiciones/4406?temporada=2026&vista=llaves&llave=apertura',
        wait: const Duration(minutes: 1),
      ),
    ),
    _Scene(
      'llaves_libertadores_2025',
      (tester) => goTo(
        tester,
        '/competiciones/4501?temporada=2025&vista=llaves',
        wait: const Duration(minutes: 1),
      ),
      continental: true,
    ),
    _Scene(
      'ficha_boca',
      (tester) =>
          goTo(tester, '/equipos/135156', wait: const Duration(minutes: 5)),
      continental: true,
    ),
    // Fase E4: el selector de competición abierto (hoja < 600, menú
    // ≥ 600) y el fixture con un partido en el panel de detalle.
    _Scene('competiciones_selector', (tester) async {
      await goTo(
        tester,
        '/competiciones/4501?temporada=2026&fase=eliminatorias',
      );
      await tester.tap(find.byKey(FixtureSelectors.competitionSelectorKey));
      await tester.pumpAndSettle();
    }, continental: true),
    _Scene('fixture_panel_detalle', (tester) async {
      await goTo(
        tester,
        '/competiciones/4406?temporada=2026&fase=clausura&ronda=12',
      );
      await tester.tap(find.byType(MatchCard).first);
      await tester.pumpAndSettle();
    }),
    _Scene('detalle_primera', (tester) async {
      await goTo(
        tester,
        '/competiciones/4406?temporada=2026&fase=clausura&ronda=11',
      );
      await goTo(tester, '/partidos/2398104');
    }),
    _Scene('detalle_serie_penales', (tester) async {
      await goTo(
        tester,
        '/competiciones/4501?temporada=2026&fase=eliminatorias'
        '&ronda=125&etapa=eliminatoria',
      );
      await goTo(tester, '/partidos/2600654');
    }, continental: true),
    // Fase E6: los demás cuadros (pendientes y en juego, Playoffs y final
    // sin dato, partido único con penales) y el detalle de una serie
    // definida por el global, de un partido único por penales y de uno
    // programado con nombres largos.
    _Scene(
      'llaves_libertadores_2026',
      (tester) => goTo(
        tester,
        '/competiciones/4501?temporada=2026&vista=llaves',
        wait: const Duration(minutes: 1),
      ),
      continental: true,
    ),
    _Scene(
      'llaves_sudamericana_2025',
      (tester) => goTo(
        tester,
        '/competiciones/4724?temporada=2025&vista=llaves',
        wait: const Duration(minutes: 1),
      ),
      continental: true,
    ),
    _Scene(
      'llaves_copa_argentina',
      (tester) => goTo(
        tester,
        '/competiciones/4500?temporada=2026&vista=llaves',
        wait: const Duration(minutes: 1),
      ),
    ),
    _Scene('detalle_serie_global', (tester) async {
      await goTo(
        tester,
        '/competiciones/4501?temporada=2025&vista=llaves',
        wait: const Duration(minutes: 1),
      );
      await goTo(tester, '/partidos/2262164');
    }, continental: true),
    _Scene('detalle_copa_penales', (tester) async {
      await goTo(
        tester,
        '/competiciones/4500?temporada=2026&vista=llaves',
        wait: const Duration(minutes: 1),
      );
      await goTo(tester, '/partidos/2540103');
    }),
    _Scene('detalle_programado', (tester) async {
      await goTo(
        tester,
        '/competiciones/4406?temporada=2026&fase=clausura&ronda=13',
      );
      await goTo(tester, '/partidos/2398141');
    }),
    // La serie con penales en el panel de 440 px (una columna).
    _Scene('fixture_panel_detalle_serie', (tester) async {
      await goTo(
        tester,
        '/competiciones/4501?temporada=2026&fase=eliminatorias'
        '&ronda=125&etapa=eliminatoria',
      );
      final vuelta = find.byWidgetPredicate(
        (w) => w is MatchCard && w.match.id == 2600654,
      );
      await tester.ensureVisible(vuelta);
      await tester.pumpAndSettle();
      await tester.tap(vuelta);
      await tester.pumpAndSettle();
    }, continental: true),
    // Fase E7: Equipos, Favoritos y Ajustes con los componentes comunes.
    _Scene('busqueda', (tester) => goTo(tester, '/equipos?q=gimnasia')),
    _Scene(
      'favoritos',
      (tester) => goTo(tester, '/favoritos'),
      seed: _saveBoca,
    ),
    _Scene('favoritos_vacio', (tester) => goTo(tester, '/favoritos')),
    _Scene('ajustes', (tester) => goTo(tester, '/ajustes')),
  ];

  // Matriz: todas las pantallas a 360 y 1280 en claro y oscuro; las de
  // mayor uso también a 768 y 1920 (claro); y tres al 200 % en teléfono.
  const wideScenes = {
    'inicio',
    'fixture_primera',
    'fixture_libertadores_series',
    'tabla_anual',
    'llaves_libertadores_2025',
    // Fase E5: tabla de grupos y calendario en toda la matriz de anchos.
    'tabla_grupo_libertadores',
    'calendario',
  };
  const scaledScenes = {
    'inicio',
    'inicio_favorito',
    'fixture_libertadores_series',
    'fixture_primera',
    'tabla_zona',
    'tabla_grupo_libertadores',
    'calendario',
    'llaves_libertadores_2025',
    'competiciones_selector',
    'tabla_anual',
    'tabla_favorito',
    // Fase E6.
    'llaves_primera',
    'llaves_libertadores_2026',
    'llaves_copa_argentina',
    'ficha_boca',
    'detalle_primera',
    'detalle_serie_penales',
    'detalle_programado',
    // Fase E7.
    'busqueda',
    'favoritos',
    'ajustes',
  };
  // Fase E7: toda la matriz de anchos (360 · 411 · 768 · 800 · 1280 ·
  // 1920) en las pantallas que todavía no la tenían.
  const e7Scenes = {'inicio', 'busqueda', 'favoritos', 'ajustes'};
  // Fase E4: Competiciones también en el teléfono de 411 dp y en la tablet
  // vertical (800 px).
  const competitionScenes = {
    'fixture_primera',
    'fixture_libertadores_series',
    'tabla_grupo_libertadores',
    'calendario',
    'llaves_primera',
    'competiciones_selector',
    // Fase E5.
    'tabla_anual',
    // Fase E6: llaves, ficha y detalle.
    'llaves_libertadores_2025',
    'llaves_libertadores_2026',
    'ficha_boca',
    'detalle_serie_penales',
    'detalle_programado',
  };
  // Solo en escritorio (el panel existe desde 1200 px).
  const desktopOnly = {'fixture_panel_detalle', 'fixture_panel_detalle_serie'};

  for (final scene in scenes) {
    if (desktopOnly.contains(scene.name)) {
      for (final brightness in Brightness.values) {
        scene.register(VisualSizes.tabletLandscape, brightness);
      }
      scene.register(VisualSizes.desktop, Brightness.light);
      scene.register(
        VisualSizes.tabletLandscape,
        Brightness.light,
        textScale: 2,
      );
      continue;
    }
    for (final brightness in Brightness.values) {
      for (final size in [VisualSizes.phone, VisualSizes.tabletLandscape]) {
        scene.register(size, brightness);
      }
    }
    if (competitionScenes.contains(scene.name)) {
      scene.register(VisualSizes.phoneWide, Brightness.light);
      scene.register(VisualSizes.tablet800, Brightness.light);
    }
    if (wideScenes.contains(scene.name) || e7Scenes.contains(scene.name)) {
      scene.register(VisualSizes.tabletPortrait, Brightness.light);
      scene.register(VisualSizes.desktop, Brightness.light);
    }
    if (e7Scenes.contains(scene.name) &&
        !competitionScenes.contains(scene.name)) {
      scene.register(VisualSizes.phoneWide, Brightness.light);
      scene.register(VisualSizes.tablet800, Brightness.light);
    }
    if (scaledScenes.contains(scene.name)) {
      scene.register(VisualSizes.phone, Brightness.light, textScale: 2);
    }
  }

  group('estados', () {
    for (final brightness in Brightness.values) {
      final theme = _themeName(brightness);
      testWidgets('error de la API · 360 · $theme', (tester) async {
        await withRealShadows(() async {
          useBrightness(tester, brightness);
          await pumpApp(
            tester,
            VisualSizes.phone,
            respond: (url) => http.Response('error', 500),
          );
          await expectScreen(tester, 'estado_error_api_360_$theme');
        });
      });

      testWidgets('límite de consultas (429) · 360 · $theme', (tester) async {
        await withRealShadows(() async {
          useBrightness(tester, brightness);
          var limited = false;
          await pumpApp(
            tester,
            VisualSizes.phone,
            respond: (url) {
              if (limited) return null;
              limited = true;
              return http.Response('{"error": "Too Many Requests"}', 429);
            },
            settle: false,
          );
          await tester.pump(const Duration(seconds: 1));
          await expectScreen(tester, 'estado_limite_360_$theme');
          // Deja terminar la pausa y las cargas antes de cerrar el test.
          await tester.pump(const Duration(seconds: 61));
          await tester.pumpAndSettle();
        });
      });

      // Fase R3: TheSportsDB sigue respondiendo 429 y el scheduler agota
      // los reintentos; la pausa del último 429 todavía corre.
      testWidgets('límite agotado · 360 · $theme', (tester) async {
        await withRealShadows(() async {
          useBrightness(tester, brightness);
          await pumpApp(
            tester,
            VisualSizes.phone,
            respond: (url) =>
                http.Response('{"error": "Too Many Requests"}', 429),
            settle: false,
          );
          await _pumpUntilRetry(tester);
          await expectScreen(tester, 'estado_limite_agotado_360_$theme');
          await tester.pump(const Duration(minutes: 10));
          await tester.pumpAndSettle();
        });
      });
    }

    // Fase R3: el aviso de la pausa en teléfonos y con texto grande.
    for (final (size, scale, brightness) in [
      (VisualSizes.phoneWide, 1.0, Brightness.light),
      (VisualSizes.phone, 2.0, Brightness.light),
      (VisualSizes.phoneWide, 2.0, Brightness.dark),
    ]) {
      final name = [
        'estado_limite',
        '${size.width.toInt()}',
        if (scale != 1) '${(scale * 100).toInt()}',
        _themeName(brightness),
      ].join('_');
      testWidgets(name, (tester) async {
        await withRealShadows(() async {
          useBrightness(tester, brightness);
          if (scale != 1) useTextScale(tester, scale);
          var limited = false;
          await pumpApp(
            tester,
            size,
            respond: (url) {
              if (limited) return null;
              limited = true;
              return http.Response('{"error": "Too Many Requests"}', 429);
            },
            settle: false,
          );
          await tester.pump(const Duration(seconds: 1));
          await expectScreen(tester, name);
          await tester.pump(const Duration(seconds: 61));
          await tester.pumpAndSettle();
        });
      });
    }

    // Fase R3.1: bloqueo persistente con trabajos pendientes («último
    // intento»), a 360 y con el texto al 200 %.
    for (final scale in [1.0, 2.0]) {
      final name = [
        'estado_limite_ultimo_intento_360',
        if (scale != 1) '200',
        'claro',
      ].join('_');
      testWidgets(name, (tester) async {
        await withRealShadows(() async {
          useBrightness(tester, Brightness.light);
          if (scale != 1) useTextScale(tester, scale);
          await pumpApp(
            tester,
            VisualSizes.phone,
            respond: (url) =>
                http.Response('{"error": "Too Many Requests"}', 429),
            settle: false,
          );
          final lastAttempt = find.textContaining('Último intento');
          for (var i = 0; i < 60 && lastAttempt.evaluate().isEmpty; i++) {
            await tester.pump(const Duration(seconds: 10));
          }
          expect(lastAttempt, findsOne);
          await tester.pump();
          await expectScreen(tester, name);
          await tester.pump(const Duration(minutes: 10));
          await tester.pumpAndSettle();
        });
      });
    }

    // Fase R3: con datos guardados (Tabla Anual), un 429 en «Actualizar».
    testWidgets('límite con datos guardados · 360 · claro', (tester) async {
      await withRealShadows(() async {
        useBrightness(tester, Brightness.light);
        var limited = false;
        await pumpApp(
          tester,
          VisualSizes.phone,
          respond: (url) {
            if (!limited || !url.path.endsWith('eventsround.php')) return null;
            limited = false;
            return http.Response('{"error": "Too Many Requests"}', 429);
          },
        );
        // El logo de la competición, como en las demás escenas.
        await precacheCompetitionLogos(tester);
        await goTo(
          tester,
          '/competiciones/4406?temporada=2026&vista=tabla&tabla=anual',
          wait: const Duration(minutes: 2),
        );
        limited = true;
        await tester.tap(find.byTooltip('Actualizar'));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await expectScreen(tester, 'estado_limite_guardado_360_claro');
        await tester.pump(const Duration(minutes: 2));
        await tester.pumpAndSettle();
      });
    });
  });
}

/// Deja pasar el tiempo de a 10 s hasta que aparece «Reintentar» (el
/// scheduler agotó los reintentos), como mucho 30 minutos: con un 429
/// persistente, el Inicio en frío tarda unos 24 (cada consulta nueva abre
/// otra pausa de 240 s).
Future<void> _pumpUntilRetry(WidgetTester tester) async {
  final retry = find.text('Reintentar');
  for (var i = 0; i < 180 && retry.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(seconds: 10));
  }
  expect(retry, findsWidgets);
  await tester.pump();
}

String _themeName(Brightness b) => b == Brightness.light ? 'claro' : 'oscuro';

Future<void> _saveBoca(Database db) => FavoritesRepositoryImpl(db).save(
  FavoriteTeam.fromRef(
    recordedTeam('Boca Juniors'),
    addedAt: DateTime.utc(2026, 10, 1),
  ),
);

class _Scene {
  _Scene(this.name, this.open, {this.continental = false, this.seed});

  final String name;
  final Future<void> Function(WidgetTester tester) open;

  /// Usa la hora de las grabaciones de las copas (14/10/2026, D1).
  final bool continental;

  /// Datos guardados antes de arrancar (un favorito).
  final Future<void> Function(Database db)? seed;

  void register(Size size, Brightness brightness, {double textScale = 1}) {
    final theme = _themeName(brightness);
    final scale = textScale == 1 ? '' : '_${(textScale * 100).round()}';
    final file = '${name}_${size.width.round()}${scale}_$theme';
    testWidgets(file, (tester) async {
      await withRealShadows(() async {
        useBrightness(tester, brightness);
        if (textScale != 1) useTextScale(tester, textScale);
        await pumpApp(
          tester,
          size,
          now: continental ? continentalRecordingTime : null,
          seed: seed,
        );
        await precacheCompetitionLogos(tester);
        await open(tester);
        await expectScreen(tester, file);
      });
    });
  }
}
