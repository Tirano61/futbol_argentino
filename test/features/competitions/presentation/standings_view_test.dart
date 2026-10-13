import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/repositories/competition_repository.dart';
import 'package:futbol_argentino/features/competitions/domain/usecases/watch_standings.dart';
import 'package:futbol_argentino/features/competitions/presentation/bloc/standings_bloc.dart';
import 'package:futbol_argentino/features/competitions/presentation/bloc/competition_fixture_bloc.dart';
import 'package:futbol_argentino/features/competitions/presentation/pages/competitions_page.dart';
import 'package:futbol_argentino/features/competitions/presentation/routing/fixture_route.dart';
import 'package:futbol_argentino/features/competitions/presentation/widgets/standings_panel.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/fixture_matches.dart';

/// Rondas reales de Primera 2026 (0–16, grabadas el 11/10/2026).
FakeMatchRepository primeraRounds() => FakeMatchRepository({
  for (var r = 0; r <= 16; r++)
    r: fixtureMatches('eventsround_4406_r${r}_s2026'),
});

/// Rondas reales de Primera 2026 (0–16) y de Nacional 2026 (1–36, con
/// claves 1001–1036: el repositorio falso indexa por ronda y las tablas
/// leen lo guardado por competición).
FakeMatchRepository bothLeagues() => FakeMatchRepository({
  for (var r = 0; r <= 16; r++)
    r: fixtureMatches('eventsround_4406_r${r}_s2026'),
  for (var r = 1; r <= 36; r++)
    1000 + r: fixtureMatches('eventsround_4616_r${r}_s2026'),
});

Future<FakeMatchRepository> pumpTable(
  WidgetTester tester, {
  int competitionId = 4406,
  CompetitionsView view = CompetitionsView.table,
  String? table,
  double width = 900,
  FakeMatchRepository? matches,
}) async {
  tester.view
    ..physicalSize = Size(width, 6000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = matches ?? primeraRounds();

  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<MatchRepository>.value(value: repository),
        RepositoryProvider<CompetitionRepository>.value(
          value: FakeCompetitionRepository(
            pointersById: {
              for (final id in [4406, 4616])
                id: SchedulePointers(
                  next: fixtureMatches('eventsnextleague_$id').single,
                ),
            },
          ),
        ),
        RepositoryProvider<Clock>.value(
          value: FixedClock(DateTime.utc(2026, 10, 11, 21)),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => CompetitionsPage(
                initialEvent: FixtureOpened(competitionId: competitionId),
                initialView: view,
                initialTable: table,
              ),
            ),
            GoRoute(
              path: '/equipos/:id',
              builder: (context, state) =>
                  Scaffold(body: Text('Equipo ${state.pathParameters['id']}')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Finder get tableRows => find.descendant(
  of: find.byType(StandingsTableView),
  matching: find.byType(InkWell),
);

void main() {
  testWidgets('Tabla Anual 2026: 30 equipos, cobertura y notas', (
    tester,
  ) async {
    await pumpTable(tester);

    expect(find.text('Tabla Anual 2026'), findsWidgets);
    expect(tableRows, findsNWidgets(30));
    expect(
      find.text('Fechas consultadas 16 de 16 · 413 de 480 partidos sumados'),
      findsOne,
    );
    expect(find.text('Partidos sin sumar (67)'), findsOne);
    expect(find.textContaining('art. 24 del'), findsOne);
    expect(find.textContaining('la app no los define'), findsOne);
    expect(find.textContaining('no es la tabla oficial'), findsOne);
  });

  testWidgets('la URL elige la tabla; el selector cambia de tabla', (
    tester,
  ) async {
    await pumpTable(tester, table: 'apertura-a');

    expect(find.text('Apertura 2026 · Zona A'), findsOne);
    expect(tableRows, findsNWidgets(15));
    expect(find.textContaining('art. 9 y 10'), findsOne);
    // Boca: segundo en su zona del Apertura (como en lookuptable).
    expect(
      find.bySemanticsLabel(RegExp(r'^Posición 2: Boca Juniors\.')),
      findsOne,
    );

    await tester.tap(find.text('Clausura · Zona B'));
    await tester.pumpAndSettle();
    expect(find.text('Clausura 2026 · Zona B'), findsOne);
    expect(find.textContaining('art. 15 y 16'), findsOne);
  });

  testWidgets('Fixture | Tabla: se cambia de vista sin perder la selección', (
    tester,
  ) async {
    await pumpTable(tester, view: CompetitionsView.fixture);
    expect(find.text('Fecha 12'), findsOne);
    expect(find.byType(StandingsTableView), findsNothing);

    await tester.tap(find.text('Tabla'));
    await tester.pumpAndSettle();
    expect(tableRows, findsNWidgets(30));
    // En la vista Tabla no se elige fase.
    expect(find.widgetWithText(ChoiceChip, 'Apertura'), findsNothing);

    await tester.tap(find.text('Fixture'));
    await tester.pumpAndSettle();
    expect(find.text('Fecha 12'), findsOne);
  });

  for (final (width, visible, hidden) in [
    (360.0, ['PJ', 'DG', 'Pts'], ['PG', 'GF']),
    (900.0, ['PJ', 'PG', 'PE', 'PP', 'DG', 'Pts'], ['GF', 'GC']),
    (1280.0, ['PJ', 'PG', 'PE', 'PP', 'GF', 'GC', 'DG', 'Pts'], <String>[]),
  ]) {
    testWidgets('${width.toInt()} px: columnas según el ancho', (tester) async {
      await pumpTable(tester, width: width);

      for (final c in visible) {
        expect(find.text(c), findsOne, reason: c);
      }
      for (final c in hidden) {
        expect(find.text(c), findsNothing, reason: c);
      }
    });
  }

  testWidgets('tocar un equipo abre su ficha', (tester) async {
    await pumpTable(tester, table: 'apertura-a');

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Posición 2: Boca')));
    await tester.pumpAndSettle();

    expect(find.text('Equipo 135156'), findsOne);
  });

  testWidgets('Copa: sin tabla, sin consultas', (tester) async {
    final matches = await pumpTable(tester, competitionId: 4500);

    expect(find.text('Sin tabla'), findsOne);
    expect(find.textContaining('eliminación directa'), findsOne);
    expect(matches.synced, isEmpty);
  });

  testWidgets('Nacional: Zona A por defecto, 18 equipos, sin Tabla Anual; '
      'el selector pasa a la Zona B', (tester) async {
    await pumpTable(tester, competitionId: 4616, matches: bothLeagues());

    expect(find.text('Posiciones 2026 · Zona A'), findsOne);
    expect(tableRows, findsNWidgets(18));
    expect(find.widgetWithText(ChoiceChip, 'Zona A'), findsOne);
    expect(find.widgetWithText(ChoiceChip, 'Zona B'), findsOne);
    expect(find.textContaining('Tabla Anual'), findsNothing);
    expect(
      find.text('Fechas consultadas 36 de 36 · 307 de 342 partidos sumados'),
      findsOne,
    );
    expect(find.textContaining('art. 112 del Reglamento General'), findsOne);
    expect(find.textContaining('la app no los define'), findsOne);
    expect(
      find.bySemanticsLabel(RegExp(r'^Posición 1: Ferro Carril Oeste\.')),
      findsOne,
    );

    await tester.tap(find.text('Zona B'));
    await tester.pumpAndSettle();
    expect(find.text('Posiciones 2026 · Zona B'), findsOne);
    expect(
      find.bySemanticsLabel(RegExp(r'^Posición 1: Tristán Suárez\.')),
      findsOne,
    );
  });

  testWidgets('Nacional: la URL elige la zona; una clave de Primera muestra '
      'la Zona A', (tester) async {
    await pumpTable(
      tester,
      competitionId: 4616,
      table: 'zona-b',
      matches: bothLeagues(),
    );
    expect(find.text('Posiciones 2026 · Zona B'), findsOne);

    await pumpTable(
      tester,
      competitionId: 4616,
      table: 'anual',
      matches: bothLeagues(),
    );
    expect(find.text('Posiciones 2026 · Zona A'), findsOne);
  });

  testWidgets('al cambiar de competición se muestra la primera tabla de la '
      'nueva', (tester) async {
    await pumpTable(tester, table: 'clausura-b', matches: bothLeagues());
    expect(find.text('Clausura 2026 · Zona B'), findsOne);

    await tester.tap(find.text('Nacional'));
    await tester.pumpAndSettle();
    expect(find.text('Posiciones 2026 · Zona A'), findsOne);

    await tester.tap(find.text('Primera'));
    await tester.pumpAndSettle();
    expect(find.text('Tabla Anual 2026'), findsWidgets);
  });

  testWidgets('liga sin tabla anual con las zonas sin verificar: lo dice '
      'en lugar de la tabla', (tester) async {
    final bloc = StandingsBloc(
      watchStandings: WatchStandings(
        bothLeagues(),
        catalog: [_nacionalWithoutFerro()],
      ),
      clock: FixedClock(DateTime.utc(2026, 10, 11, 21)),
    )..add(const StandingsStarted(competitionId: 4616, season: Season(2026)));
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: StandingsPanel(
              tableKey: null,
              onTableSelected: (_) {},
              onRefresh: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zonas no verificadas'), findsOne);
    expect(find.textContaining('Ferro Carril Oeste no tiene zona.'), findsOne);
    expect(find.byType(StandingsTableView), findsNothing);
  });

  testWidgets('actualizar sin consultas a la red avisa «Ya está '
      'actualizado»', (tester) async {
    final matches = primeraRounds()..syncFetches = false;
    await pumpTable(tester, matches: matches);
    matches.synced.clear();

    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();

    // Refresco manual: la fecha 12 (partidos de hoy sin terminar) con P0.
    expect(matches.synced.where((s) => s.force).map((s) => s.query.apiRound), [
      12,
    ]);
    expect(find.text('Ya está actualizado.'), findsOne);
  });
}

/// Nacional con las zonas cambiadas en el test (Ferro sin zona): los
/// partidos no coinciden con el catálogo.
CompetitionDefinition _nacionalWithoutFerro() {
  const real = CompetitionCatalog.primeraNacional;
  final format = real.standingsFor(const Season(2026)) as LeagueZones;
  return CompetitionDefinition(
    id: real.id,
    name: real.name,
    shortName: real.shortName,
    format: real.format,
    rules: real.rules,
    standingsBySeason: {
      2026: LeagueZones(
        zones: {
          'A': {...format.zones['A']!}..remove(137774),
          'B': format.zones['B']!,
        },
        regularRounds: format.regularRounds,
        interzonalsPerTeam: format.interzonalsPerTeam,
        tieBreak: format.tieBreak,
        tableArticle: format.tableArticle,
        tieBreakArticle: format.tieBreakArticle,
        relegationNote: format.relegationNote,
        regulation: format.regulation,
      ),
    },
  );
}
