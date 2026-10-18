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
import 'package:futbol_argentino/features/competitions/presentation/widgets/view_tabs.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/fixture_matches.dart';
import '../../../helpers/recorded_app.dart';

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

/// Rondas reales de Libertadores 2026 (1–6, grabadas el 14/10/2026; las
/// 1–3 traen también las fases previas).
FakeMatchRepository libertadoresGroups() => FakeMatchRepository({
  for (var r = 1; r <= 6; r++)
    r: fixtureMatches('eventsround_4501_r${r}_s2026'),
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
              for (final id in [4406, 4616, 4501])
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

/// Solo el panel, con [catalog] en lugar del de la app.
Future<void> pumpPanel(
  WidgetTester tester, {
  required FakeMatchRepository matches,
  required List<CompetitionDefinition> catalog,
  required int competitionId,
  required Season season,
}) async {
  final bloc = StandingsBloc(
    watchStandings: WatchStandings(matches, catalog: catalog),
    clock: FixedClock(DateTime.utc(2026, 10, 11, 21)),
  )..add(StandingsStarted(competitionId: competitionId, season: season));
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
}

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

    // Las tablas van en una fila que se desplaza (Hito E, E4).
    await tester.ensureVisible(find.text('Clausura · Zona B'));
    await tester.pumpAndSettle();
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

  testWidgets('Copa: sin segmento «Tabla»; `vista=tabla` abre el Fixture, '
      'sin bajar la temporada', (tester) async {
    final matches = await pumpTable(tester, competitionId: 4500);

    expect(find.text('Tabla'), findsNothing);
    expect(find.text('Sin tabla'), findsNothing);
    expect(find.text('Fixture'), findsOne);
    expect(find.text('Llaves'), findsOne);
    expect(find.byType(StandingsPanel), findsNothing);
    expect(matches.synced, isEmpty);
  });

  testWidgets('con la Tabla abierta, pasar a una competición sin tabla '
      'vuelve al Fixture', (tester) async {
    await pumpTable(tester, matches: bothLeagues());
    expect(find.text('Tabla Anual 2026'), findsWidgets);

    await selectCompetition(tester, 'Copa Argentina');

    expect(find.byType(StandingsPanel), findsNothing);
    expect(find.text('Tabla'), findsNothing);
    final tabs = tester.widget<ViewTabs>(find.byType(ViewTabs));
    expect(tabs.view, CompetitionsView.fixture);

    // Al volver, «Tabla» está otra vez (sin abrirse sola).
    await selectCompetition(tester, 'Primera');
    expect(find.text('Tabla'), findsOne);
    expect(find.byType(StandingsPanel), findsNothing);
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

    await selectCompetition(tester, 'Nacional');
    expect(find.text('Posiciones 2026 · Zona A'), findsOne);

    await selectCompetition(tester, 'Primera');
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

  testWidgets('Libertadores 2026: 8 grupos, la URL elige el grupo, notas '
      'del Manual de Clubes', (tester) async {
    await pumpTable(
      tester,
      competitionId: 4501,
      table: 'grupo-g',
      matches: libertadoresGroups(),
    );

    expect(find.text('Fase de grupos 2026 · Grupo G'), findsOne);
    for (final g in 'ABCDEFGH'.split('')) {
      expect(find.widgetWithText(ChoiceChip, 'Grupo $g'), findsOne);
    }
    expect(tableRows, findsNWidgets(4));
    expect(
      find.bySemanticsLabel(RegExp(r'^Posición 1: LDU Quito\.')),
      findsOne,
    );
    expect(find.bySemanticsLabel(RegExp(r'^Posición 2: Mirassol\.')), findsOne);
    expect(
      find.text('Fechas consultadas 6 de 6 · 12 de 12 partidos sumados'),
      findsOne,
    );
    expect(
      find.textContaining('menos tarjetas amarillas y sorteo (2.4.2).'),
      findsOne,
    );
    expect(
      find.textContaining(
        '(2.4.1 del Manual de Clubes CONMEBOL Libertadores '
        '2026)',
      ),
      findsOne,
    );
    expect(find.textContaining('se miran una sola vez'), findsOne);
    expect(
      find.textContaining('a los playoffs de octavos de la Copa Sudamericana'),
      findsOne,
    );

    await tester.tap(find.text('Grupo D'));
    await tester.pumpAndSettle();
    expect(find.text('Fase de grupos 2026 · Grupo D'), findsOne);
    expect(
      find.bySemanticsLabel(RegExp(r'^Posición 3: Boca Juniors\.')),
      findsOne,
    );
  });

  testWidgets('copa con un grupo sin verificar: los demás grupos y el '
      'aviso', (tester) async {
    await pumpPanel(
      tester,
      matches: libertadoresGroups(),
      catalog: [_libertadoresWithBocaInA()],
      competitionId: 4501,
      season: const Season(2026),
    );

    expect(find.widgetWithText(ChoiceChip, 'Grupo A'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Grupo D'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Grupo B'), findsOne);
    expect(find.text('Fase de grupos 2026 · Grupo B'), findsOne);
    expect(
      find.textContaining(
        'Grupos no verificados: las tablas de esos grupos no se muestran.',
      ),
      findsOne,
    );
  });

  testWidgets('copa sin grupos verificados en la temporada: lo dice', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      matches: libertadoresGroups(),
      catalog: CompetitionCatalog.all,
      competitionId: 4501,
      season: const Season(2027),
    );

    expect(find.text('Sin tabla'), findsOne);
    expect(
      find.text(
        'Todavía no hay grupos verificados con el reglamento de la Copa '
        'Libertadores 2027.',
      ),
      findsOne,
    );
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
    category: real.category,
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

/// Libertadores 2026 con Boca (Grupo D) pasado al Grupo A en el test: los
/// partidos de los dos grupos no coinciden con el catálogo.
CompetitionDefinition _libertadoresWithBocaInA() {
  const real = CompetitionCatalog.copaLibertadores;
  final format = real.standingsFor(const Season(2026)) as GroupStage;
  return CompetitionDefinition(
    id: real.id,
    name: real.name,
    shortName: real.shortName,
    category: real.category,
    format: real.format,
    rules: real.rules,
    standingsBySeason: {
      2026: GroupStage(
        groups: {
          ...format.groups,
          'A': {...format.groups['A']!, 135156},
          'D': {...format.groups['D']!}..remove(135156),
        },
        regularRounds: format.regularRounds,
        tieBreak: format.tieBreak,
        pointsArticle: format.pointsArticle,
        tieBreakArticle: format.tieBreakArticle,
        qualificationNote: format.qualificationNote,
        regulation: format.regulation,
      ),
    },
  );
}
