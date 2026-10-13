import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/competitions/domain/repositories/competition_repository.dart';
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
            pointers: SchedulePointers(
              next: fixtureMatches('eventsnextleague_4406').single,
            ),
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
