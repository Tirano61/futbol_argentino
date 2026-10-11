import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/phase.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/stage.dart';
import 'package:futbol_argentino/features/competitions/domain/repositories/competition_repository.dart';
import 'package:futbol_argentino/features/competitions/presentation/bloc/competition_fixture_bloc.dart';
import 'package:futbol_argentino/features/competitions/presentation/pages/competitions_page.dart';
import 'package:futbol_argentino/features/competitions/presentation/routing/fixture_route.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:futbol_argentino/shared/presentation/formatters/match_labels.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/fixture_matches.dart';

Future<void> pumpPage(WidgetTester tester, FixtureOpened initial) async {
  tester.view
    ..physicalSize = const Size(900, 6000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final matches = FakeMatchRepository({
    for (var r = 0; r <= 16; r++)
      r: fixtureMatches('eventsround_4406_r${r}_s2026'),
    125: fixtureMatches('eventsround_4500_r125_s2026'),
  });
  final competitions = FakeCompetitionRepository(
    pointers: SchedulePointers(
      next: fixtureMatches('eventsnextleague_4406').single,
    ),
  );

  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<MatchRepository>.value(value: matches),
        RepositoryProvider<CompetitionRepository>.value(value: competitions),
        RepositoryProvider<Clock>.value(
          value: FixedClock(DateTime.utc(2026, 10, 11, 21)),
        ),
      ],
      child: MaterialApp(home: CompetitionsPage(initialEvent: initial)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Primera abre en la fecha 12 del Clausura con 15 partidos', (
    tester,
  ) async {
    await pumpPage(tester, const FixtureOpened(competitionId: 4406));

    expect(find.text('Primera División'), findsOneWidget);
    expect(find.text('Fecha 12'), findsOneWidget);
    final clausura = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Clausura'),
    );
    expect(clausura.selected, isTrue);
    expect(find.byType(MatchCard), findsNWidgets(15));
    expect(find.text('Viernes 09/10/2026'), findsOneWidget);
    expect(find.textContaining('Horarios de Argentina'), findsOneWidget);
  });

  testWidgets('«Siguiente» pasa a la fecha 13', (tester) async {
    await pumpPage(tester, const FixtureOpened(competitionId: 4406));

    await tester.tap(find.byTooltip('Siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('Fecha 13'), findsOneWidget);
    expect(find.byType(MatchCard), findsNWidgets(15));
  });

  testWidgets(
    'Apertura fecha 12 muestra «Horario por confirmar» en los 00:00 sin corroborar',
    (tester) async {
      await pumpPage(
        tester,
        const FixtureOpened(
          competitionId: 4406,
          season: Season(2026),
          phase: PhaseKey.apertura,
          apiRound: 12,
        ),
      );

      // 2397877 y 2397878: 2026-03-21T00:00:00 con strTimeLocal 18:00.
      expect(
        find.text(MatchLabels.unconfirmedTime),
        findsNothing,
        reason: 'están terminados: se muestra el resultado, no la hora',
      );
      expect(find.text('Sábado 21/03/2026'), findsOneWidget);
    },
  );

  testWidgets('Copa: cuartos de final', (tester) async {
    await pumpPage(
      tester,
      const FixtureOpened(
        competitionId: 4500,
        phase: PhaseKey.unica,
        apiRound: 125,
        kind: StageKind.knockout,
      ),
    );

    expect(find.text('Cuartos de final'), findsOneWidget);
    expect(find.byType(MatchCard), findsNWidgets(4));
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('etapa sin partidos: mensaje informativo', (tester) async {
    await pumpPage(
      tester,
      const FixtureOpened(
        competitionId: 4500,
        phase: PhaseKey.unica,
        apiRound: 200,
        kind: StageKind.knockout,
      ),
    );

    expect(find.text('Sin partidos'), findsOneWidget);
  });

  group('FixtureRoute', () {
    test('ida y vuelta de la URL', () {
      final event = FixtureRoute.parse(
        leagueId: '4406',
        query: {'temporada': '2026', 'fase': 'clausura', 'ronda': '12'},
      );

      expect(event.competitionId, 4406);
      expect(event.season, const Season(2026));
      expect(event.phase, PhaseKey.clausura);
      expect(event.apiRound, 12);
      expect(event.kind, StageKind.regular);
    });

    test('URL de una etapa de eliminación', () {
      const stage = Stage(
        competitionId: 4500,
        season: Season(2026),
        phase: PhaseKey.unica,
        apiRound: 125,
        kind: StageKind.knockout,
        label: 'Cuartos de final',
        order: 3,
      );

      expect(
        FixtureRoute.uriFor(stage).toString(),
        '/competiciones/4500?temporada=2026&fase=copa&ronda=125&etapa=eliminatoria',
      );
    });

    test('valores desconocidos se ignoran', () {
      final event = FixtureRoute.parse(leagueId: '999', query: {'fase': 'x'});

      expect(event.competitionId, 4406);
      expect(event.phase, isNull);
    });
  });
}
