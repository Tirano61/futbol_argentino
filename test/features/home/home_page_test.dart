import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/domain/repositories/competition_repository.dart';
import 'package:futbol_argentino/features/favorites/domain/entities/favorite_team.dart';
import 'package:futbol_argentino/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:futbol_argentino/features/home/presentation/pages/home_page.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_teams.dart';
import '../../helpers/fakes.dart';
import '../../helpers/favorites.dart';
import '../../helpers/recorded_home.dart';

const offline = NetworkFailure(
  issue: NetworkIssue.connection,
  detail: 'Failed host lookup',
);

FakeCompetitionRepository recordedCompetitions({
  Map<int, Failure> failures = const {},
}) => FakeCompetitionRepository(
  pointersById: {
    for (final d in homeCompetitions) d.id: recordedPointers(d.id),
  },
  failuresById: failures,
);

Future<void> pumpHome(
  WidgetTester tester, {
  FakeMatchRepository? matches,
  FakeCompetitionRepository? competitions,
  FavoritesRepository? favorites,
  bool showDiagnostics = false,
  bool settle = true,
}) async {
  // Domingo 11/10/2026, 17:00 en Argentina.
  final clock = FixedClock(DateTime.utc(2026, 10, 11, 20));
  tester.view
    ..physicalSize = const Size(900, 12000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  Widget placeholder(String text) => Scaffold(body: Text(text));
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => HomePage(showDiagnostics: showDiagnostics),
      ),
      GoRoute(
        path: '/equipos',
        builder: (context, state) => placeholder('Pantalla de equipos'),
      ),
      GoRoute(
        path: '/competiciones/:id',
        builder: (context, state) =>
            placeholder('Fixture ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/favoritos/:id',
        builder: (context, state) =>
            placeholder('Favorito ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/partidos/:id',
        builder: (context, state) =>
            placeholder('Partido ${state.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<MatchRepository>.value(
          value: matches ?? FakeMatchRepository(recordedRounds()),
        ),
        RepositoryProvider<CompetitionRepository>.value(
          value: competitions ?? recordedCompetitions(),
        ),
        RepositoryProvider<Clock>.value(value: clock),
      ],
      child: withFavorites(
        favorites: favorites ?? await outsideFakeAsync(tester, memoryFavorites),
        clock: clock,
        child: MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

/// Favoritos que se leen cuando el test lo decide.
class _PendingFavorites implements FavoritesRepository {
  final controller = StreamController<List<FavoriteTeam>>.broadcast();

  @override
  Stream<List<FavoriteTeam>> watchAll() => controller.stream;

  @override
  Future<bool> contains(int teamId) async => false;

  @override
  Future<void> save(FavoriteTeam team) async {}

  @override
  Future<void> remove(int teamId) async {}
}

void main() {
  testWidgets('Hoy, Próximos y Recientes con datos reales', (tester) async {
    await pumpHome(tester);

    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Domingo 11/10/2026'), findsOneWidget);
    expect(find.text('Próximos 7 días'), findsOneWidget);
    expect(find.text('Recientes'), findsOneWidget);
    // 17 de hoy + 37 próximos + 8 de ayer.
    expect(find.byType(MatchCard), findsNWidgets(62));
    expect(find.text('Sábado 10/10/2026'), findsOneWidget);
    expect(find.text('Domingo 18/10/2026'), findsOneWidget);
    expect(find.text('Primera División · Clausura · Fecha 12'), findsWidgets);
    expect(find.text('Primera Nacional · Fecha 34'), findsNWidgets(18));
    expect(find.textContaining('Horarios de Argentina'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('los accesos llevan a cada fixture', (tester) async {
    await pumpHome(tester);

    for (final d in CompetitionCatalog.all) {
      expect(find.widgetWithText(ActionChip, d.name), findsOneWidget);
    }
    // Agrupados por categoría (D2), en el orden del catálogo.
    final headers = [
      for (final label in [
        'Primera División',
        'Ascenso',
        'Copas nacionales',
        'Copas internacionales',
      ])
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is Semantics && (w.properties.header ?? false),
          ),
          matching: find.text(label),
        ),
    ];
    double top(Finder f) => tester.getTopLeft(f).dy;
    final tops = [for (final h in headers) top(h)];
    expect(tops, orderedEquals([...tops]..sort()));
    // La C (Ascenso) antes de las copas nacionales.
    expect(
      top(find.widgetWithText(ActionChip, 'Primera C')),
      lessThan(top(headers[2])),
    );
    // Las copas internacionales (Fase D3), después de la Copa Argentina.
    expect(
      top(find.widgetWithText(ActionChip, 'Copa Argentina')),
      lessThan(top(headers[3])),
    );
    await tester.tap(find.widgetWithText(ActionChip, 'Copa Argentina'));
    await tester.pumpAndSettle();

    expect(find.text('Fixture 4500'), findsOneWidget);
  });

  testWidgets('el acceso al buscador abre Equipos', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('Buscar equipo'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla de equipos'), findsOneWidget);
  });

  testWidgets('tocar un partido abre su detalle', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const ValueKey(2398124)));
    await tester.pumpAndSettle();

    expect(find.text('Partido 2398124'), findsOneWidget);
  });

  testWidgets('sin partidos en la ventana: mensajes por sección', (
    tester,
  ) async {
    await pumpHome(
      tester,
      matches: FakeMatchRepository(const {}),
      competitions: FakeCompetitionRepository(),
    );

    expect(find.text('No hay partidos hoy.'), findsOneWidget);
    expect(
      find.text('No hay partidos en los próximos 7 días.'),
      findsOneWidget,
    );
    expect(find.text('No hubo partidos ayer.'), findsOneWidget);
    expect(find.byType(MatchCard), findsNothing);
  });

  testWidgets('una competición sin datos: aviso y el resto visible', (
    tester,
  ) async {
    await pumpHome(
      tester,
      competitions: recordedCompetitions(failures: {4406: offline}),
    );

    expect(find.text('No se pudo cargar: Primera División.'), findsOneWidget);
    expect(find.text('Primera Nacional · Fecha 33'), findsWidgets);
    expect(find.textContaining('Primera División ·'), findsNothing);
  });

  testWidgets('datos guardados con error: aviso de datos guardados', (
    tester,
  ) async {
    await pumpHome(
      tester,
      matches: FakeMatchRepository(recordedRounds(), refreshError: offline),
    );

    expect(find.textContaining('Mostrando datos guardados'), findsOneWidget);
    expect(find.byType(MatchCard), findsNWidgets(62));
  });

  testWidgets('sin red y sin nada guardado: error con reintento', (
    tester,
  ) async {
    await pumpHome(
      tester,
      competitions: FakeCompetitionRepository(failure: offline),
    );

    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byType(MatchCard), findsNothing);
  });

  testWidgets('«Actualizar» fuerza la consulta', (tester) async {
    final competitions = recordedCompetitions();
    await pumpHome(tester, competitions: competitions);

    // El cierre del stream de la carga inicial se agenda fuera de la zona
    // de FakeAsync: una vuelta real del event loop deja terminar al handler
    // (si no, `droppable` descarta el refresco).
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();

    expect(competitions.pointerCalls.where((c) => c.force), hasLength(3));
    expect(find.byType(MatchCard), findsNWidgets(62));
    // Los repositorios devolvieron la misma hora de descarga: no hubo nada
    // nuevo que pedir (refresco dentro de los 30 s).
    expect(
      find.text('Ya está actualizado: los datos son de las 17:35.'),
      findsOneWidget,
    );
  });

  testWidgets('acceso al diagnóstico solo si está habilitado', (tester) async {
    await pumpHome(tester);
    expect(find.byTooltip('Diagnóstico de la API'), findsNothing);

    await pumpHome(tester, showDiagnostics: true);
    expect(find.byTooltip('Diagnóstico de la API'), findsOneWidget);
  });

  group('Tus equipos', () {
    testWidgets('el Inicio espera a tenerlos: no aparecen después', (
      tester,
    ) async {
      final favorites = _PendingFavorites();
      await pumpHome(tester, favorites: favorites, settle: false);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MatchCard), findsNothing);
      expect(find.bySemanticsLabel('Cargando partidos'), findsOneWidget);

      favorites.controller.add(const []);
      await tester.pumpAndSettle();

      expect(find.text('Tus equipos'), findsOneWidget);
      expect(find.byType(MatchCard), findsNWidgets(62));
    });

    testWidgets('si no se pueden leer, lo dice y muestra el resto', (
      tester,
    ) async {
      final favorites = _PendingFavorites();
      await pumpHome(tester, favorites: favorites, settle: false);
      await tester.pump(const Duration(milliseconds: 100));

      favorites.controller.addError(StateError('base local'));
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudieron leer tus equipos guardados.'),
        findsOneWidget,
      );
      expect(find.byType(MatchCard), findsNWidgets(62));
    });

    testWidgets('sin favoritos: explica cómo agregarlos', (tester) async {
      await pumpHome(tester);

      expect(find.text('Tus equipos'), findsOneWidget);
      expect(
        find.textContaining('Tocá la estrella de un equipo'),
        findsOneWidget,
      );
    });

    testWidgets('próximo y último de cada favorito, sin peticiones extra', (
      tester,
    ) async {
      final without = FakeMatchRepository(recordedRounds());
      await pumpHome(tester, matches: without);

      final favorites = await outsideFakeAsync(tester, memoryFavorites);
      final boca = recordedTeam('Boca Juniors');
      await outsideFakeAsync(
        tester,
        () => favorites.save(
          FavoriteTeam.fromRef(boca, addedAt: DateTime.utc(2026, 10, 1)),
        ),
      );
      final matches = FakeMatchRepository(recordedRounds());
      await pumpHome(tester, matches: matches, favorites: favorites);

      expect(find.widgetWithText(ListTile, 'Boca Juniors'), findsOneWidget);
      expect(
        find.text(
          'Próximo · Domingo 18/10/2026\n'
          'Primera División · Clausura · Fecha 13',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Último · Viernes 09/10/2026\n'
          'Primera División · Clausura · Fecha 12',
        ),
        findsOneWidget,
      );
      // «Tus equipos» va antes de «Hoy».
      expect(
        tester.getTopLeft(find.text('Tus equipos')).dy <
            tester.getTopLeft(find.text('Hoy')).dy,
        isTrue,
      );
      // Solo lee lo guardado: las mismas consultas que sin favoritos.
      expect(matches.calls, hasLength(without.calls.length));
      expect(matches.synced, isEmpty);

      await tester.tap(find.widgetWithText(ListTile, 'Boca Juniors'));
      await tester.pumpAndSettle();
      expect(find.text('Favorito ${boca.id}'), findsOneWidget);
    });

    testWidgets('favorito sin partidos guardados', (tester) async {
      // Equipo real de los 32avos de la Copa que no juega en las rondas
      // que carga el Inicio.
      final inRounds = {
        for (final round in recordedRounds().values)
          for (final m in round) ...[m.home.id, m.away.id],
      };
      final team = recordedTeamSummaries()
          .map((s) => s.team)
          .firstWhere((t) => !inRounds.contains(t.id));
      final favorites = await outsideFakeAsync(tester, memoryFavorites);
      await outsideFakeAsync(
        tester,
        () => favorites.save(
          FavoriteTeam.fromRef(team, addedAt: DateTime.utc(2026, 10, 1)),
        ),
      );
      await pumpHome(tester, favorites: favorites);

      expect(find.widgetWithText(ListTile, team.name), findsOneWidget);
      expect(find.textContaining('Sin partidos guardados'), findsOneWidget);
    });
  });
}
