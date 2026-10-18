import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/result/data_result.dart';
import 'package:futbol_argentino/core/sync/sync_scheduler.dart';
import 'package:futbol_argentino/core/time/calendar_month.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/competitions/domain/repositories/competition_repository.dart';
import 'package:futbol_argentino/features/competitions/presentation/bloc/competition_fixture_bloc.dart';
import 'package:futbol_argentino/features/competitions/presentation/pages/competitions_page.dart';
import 'package:futbol_argentino/features/competitions/presentation/routing/fixture_route.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_day_list.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_group.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/fixture_matches.dart';

/// Rondas reales de Primera 2026 (0–16, grabadas el 11/10/2026), todas
/// guardadas y vigentes salvo las de [missing].
FakeMatchRepository primeraStored({Set<int> missing = const {}}) {
  final repository = FakeMatchRepository({
    for (var r = 0; r <= 16; r++)
      r: fixtureMatches('eventsround_4406_r${r}_s2026'),
  });
  for (var r = 0; r <= 16; r++) {
    if (!missing.contains(r)) {
      repository.cacheStates[r] = const RoundCacheState(
        freshness: RoundFreshness.fresh,
        isComplete: true,
      );
    }
  }
  return repository;
}

/// Al descargar una ronda (el fixture), la deja guardada y vigente, como
/// el repositorio real.
class _StoringMatchRepository extends FakeMatchRepository {
  _StoringMatchRepository(super.rounds, {super.delays});

  @override
  Stream<DataResult<List<Match>>> watchRound(
    RoundQuery query, {
    bool forceRefresh = false,
    SyncPriority priority = SyncPriority.visible,
  }) async* {
    await for (final result in super.watchRound(
      query,
      forceRefresh: forceRefresh,
      priority: priority,
    )) {
      cacheStates[query.apiRound] = const RoundCacheState(
        freshness: RoundFreshness.fresh,
        isComplete: true,
      );
      yield result;
    }
  }
}

Future<FakeMatchRepository> pumpCalendar(
  WidgetTester tester, {
  int competitionId = 4406,
  CalendarMonth? month,
  double width = 900,
  FakeMatchRepository? matches,
}) async {
  tester.view
    ..physicalSize = Size(width, 6000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = matches ?? primeraStored();

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
                initialView: CompetitionsView.calendar,
                initialMonth: month,
              ),
            ),
            GoRoute(
              path: '/partidos/:id',
              builder: (context, state) =>
                  Scaffold(body: Text('Partido ${state.pathParameters['id']}')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Finder dayCell(String label) => find.bySemanticsLabel(label);

/// El contexto (fase · etapa) va una vez, en el encabezado del grupo
/// (Hito E, E5): el grupo con ese encabezado y sus [matches] partidos.
void expectStageGroup(Finder header, int matches) {
  expect(header, findsOne);
  final group = find.ancestor(of: header, matching: find.byType(MatchGroup));
  expect(group, findsOne);
  expect(
    find.descendant(of: group, matching: find.byType(MatchCard)),
    findsNWidgets(matches),
  );
}

void main() {
  testWidgets('abre en el mes de hoy con los partidos de hoy; sin consultas', (
    tester,
  ) async {
    final matches = await pumpCalendar(tester);

    expect(find.text('Octubre 2026'), findsOne);
    expect(find.text('Domingo 11/10/2026'), findsOne);
    expect(find.byType(MatchCard), findsNWidgets(5));
    expectStageGroup(find.text('Clausura · Fecha 12'), 5);
    // Todo guardado y vigente: sin aviso y sin consultas.
    expect(find.text('Completar'), findsNothing);
    // El calendario no descarga nada (el fixture de fondo carga su etapa,
    // como con la vista «Tabla»).
    expect(matches.synced, isEmpty);
    // La grilla: cada día con su cantidad de partidos.
    expect(dayCell('Domingo 11/10/2026, hoy: 5 partidos'), findsOne);
    expect(dayCell('Domingo 18/10/2026: 15 partidos'), findsOne);
    expect(dayCell('Miércoles 14/10/2026: 1 partido'), findsOne);
    expect(dayCell('Martes 13/10/2026: sin partidos guardados'), findsOne);
  });

  testWidgets('tocar un día muestra sus partidos', (tester) async {
    await pumpCalendar(tester);

    await tester.tap(dayCell('Domingo 18/10/2026: 15 partidos'));
    await tester.pumpAndSettle();

    expect(find.text('Domingo 18/10/2026'), findsOne);
    expect(find.byType(MatchCard), findsNWidgets(15));
    expectStageGroup(find.text('Clausura · Fecha 13'), 15);

    // Un día sin partidos no se elige.
    await tester.tap(dayCell('Martes 13/10/2026: sin partidos guardados'));
    await tester.pumpAndSettle();
    expect(find.text('Domingo 18/10/2026'), findsOne);
  });

  testWidgets('meses anterior y siguiente, hasta el último con partidos', (
    tester,
  ) async {
    await pumpCalendar(tester);

    await tester.tap(find.byTooltip('Mes siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Noviembre 2026'), findsOne);
    // Fecha 15: el 01/11.
    expect(find.text('Domingo 01/11/2026'), findsOne);
    expect(find.byType(MatchCard), findsNWidgets(15));
    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(next.onPressed, isNull);

    // Junio, sin partidos (Mundial 2026).
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Junio 2026'), findsOne);
    expect(find.text('No hay partidos guardados en junio 2026.'), findsOne);
    expect(find.byType(MatchCard), findsNothing);
  });

  testWidgets('el mes de la URL; el día, el primero con partidos', (
    tester,
  ) async {
    await pumpCalendar(tester, month: const CalendarMonth(2026, 3));

    expect(find.text('Marzo 2026'), findsOne);
    expect(find.text('Domingo 01/03/2026'), findsOne);
    expect(find.byType(MatchCard), findsNWidgets(5));
    expectStageGroup(find.textContaining('Apertura · Fecha'), 5);
  });

  testWidgets('faltan fechas: aviso y «Completar» las descarga con P2', (
    tester,
  ) async {
    final matches = await pumpCalendar(
      tester,
      matches: primeraStored(missing: {14, 15, 16}),
    );

    expect(
      find.text(
        'Se muestra lo guardado: faltan consultar o actualizar 3 de 17 '
        'fechas.',
      ),
      findsOne,
    );
    expect(matches.synced, isEmpty);

    await tester.tap(find.text('Completar'));
    await tester.pumpAndSettle();

    expect(matches.synced.map((s) => s.query.apiRound), [14, 15, 16]);
    expect(matches.synced.map((s) => s.priority).toSet(), {SyncPriority.team});
  });

  testWidgets('el fixture de fondo actualiza una fecha vencida: el '
      'calendario vuelve a leer lo guardado', (tester) async {
    // La fecha 12 (la del fixture) estaba vencida; el fixture la vuelve a
    // pedir y tarda más que la lectura del calendario.
    final matches = _StoringMatchRepository(
      {
        for (var r = 0; r <= 16; r++)
          r: fixtureMatches('eventsround_4406_r${r}_s2026'),
      },
      delays: const {12: Duration(seconds: 1)},
    );
    for (var r = 0; r <= 16; r++) {
      matches.cacheStates[r] = RoundCacheState(
        freshness: r == 12 ? RoundFreshness.stale : RoundFreshness.fresh,
        isComplete: true,
      );
    }

    await pumpCalendar(tester, matches: matches);
    // Antes de que responda el fixture: la fecha 12 figura vencida.
    expect(
      find.textContaining('faltan consultar o actualizar 1 de 17'),
      findsOne,
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.textContaining('faltan consultar'), findsNothing);
    expect(matches.synced, isEmpty);
  });

  testWidgets('tocar un partido abre su pantalla', (tester) async {
    await pumpCalendar(tester);

    await tester.tap(find.byType(MatchCard).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Partido '), findsOne);
  });

  testWidgets('escritorio: el mes y los partidos lado a lado', (tester) async {
    await pumpCalendar(tester, width: 1280);

    final month = tester.getRect(find.text('Octubre 2026'));
    final card = tester.getRect(find.byType(MatchCard).first);
    expect(card.left, greaterThan(month.right));
    expect(card.top, lessThan(month.bottom + 100));
    expect(find.byType(DayHeader), findsOne);
  });

  testWidgets('Copa: etapas por nombre', (tester) async {
    final copa = FakeMatchRepository({
      for (final r in [64, 32, 16, 125, 150, 200])
        r: fixtureMatches('eventsround_4500_r${r}_s2026'),
    });
    await pumpCalendar(tester, competitionId: 4500, matches: copa);

    // Octubre: un partido el 1 y dos el 25 (el próximo día con partidos).
    expect(find.text('Octubre 2026'), findsOne);
    expect(find.text('Domingo 25/10/2026'), findsOne);
    expect(find.byType(MatchCard), findsNWidgets(2));
    expectStageGroup(find.text('Semifinales'), 2);
  });
}
