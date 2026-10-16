import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/time/calendar_day.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/phase.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/repositories/competition_repository.dart';
import 'package:futbol_argentino/features/competitions/domain/usecases/resolve_current_stage.dart';
import 'package:futbol_argentino/features/competitions/domain/usecases/watch_stage_matches.dart';
import 'package:futbol_argentino/features/competitions/presentation/bloc/competition_fixture_bloc.dart';
import 'package:futbol_argentino/features/matches/domain/entities/kickoff.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/fixture_matches.dart';

final primeraRounds = {
  for (var r = 0; r <= 16; r++)
    r: fixtureMatches('eventsround_4406_r${r}_s2026'),
};
final nacionalRounds = {
  for (final r in [1, 33, 34, 35, 36])
    r: fixtureMatches('eventsround_4616_r${r}_s2026'),
};
final copaRounds = {
  for (final r in [64, 125, 150])
    r: fixtureMatches('eventsround_4500_r${r}_s2026'),
};

CompetitionFixtureBloc buildBloc(
  FakeMatchRepository matches, {
  CompetitionRepository? competitions,
}) {
  final competitionRepo =
      competitions ??
      FakeCompetitionRepository(
        pointers: SchedulePointers(
          next: fixtureMatches('eventsnextleague_4406').single,
        ),
      );
  return CompetitionFixtureBloc(
    watchStageMatches: WatchStageMatches(matches),
    resolveCurrentStage: ResolveCurrentStage(competitionRepo),
    competitions: competitionRepo,
    clock: FixedClock(DateTime.utc(2026, 10, 11, 21)),
  );
}

List<Match> loadedMatches(CompetitionFixtureState state) =>
    (state.content as FixtureLoaded).matches.matches;

void main() {
  group('apertura del fixture', () {
    blocTest<CompetitionFixtureBloc, CompetitionFixtureState>(
      'Primera: abre en la etapa actual (Clausura, fecha 12) con 15 partidos de octubre',
      build: () => buildBloc(FakeMatchRepository(primeraRounds)),
      act: (bloc) => bloc.add(const FixtureOpened(competitionId: 4406)),
      verify: (bloc) {
        final state = bloc.state;
        expect(state.season, const Season(2026));
        expect(state.seasons, [const Season(2026), const Season(2025)]);
        expect(state.phase, PhaseKey.clausura);
        expect(state.stage!.label, 'Fecha 12');
        final matches = loadedMatches(state);
        expect(matches, hasLength(15));
        expect(
          matches.every((m) => m.kickoff.argentinaDay!.month == 10),
          isTrue,
        );
      },
    );

    blocTest<CompetitionFixtureBloc, CompetitionFixtureState>(
      'desde la URL: Apertura fecha 12 → los 15 partidos de marzo',
      build: () => buildBloc(FakeMatchRepository(primeraRounds)),
      act: (bloc) => bloc.add(
        const FixtureOpened(
          competitionId: 4406,
          season: Season(2026),
          phase: PhaseKey.apertura,
          apiRound: 12,
        ),
      ),
      verify: (bloc) {
        final matches = loadedMatches(bloc.state);
        expect(matches, hasLength(15));
        expect(
          matches.every((m) => m.kickoff.argentinaDay!.month == 3),
          isTrue,
        );
      },
    );

    blocTest<CompetitionFixtureBloc, CompetitionFixtureState>(
      'Primera Nacional fecha 33: 18 partidos',
      build: () => buildBloc(FakeMatchRepository(nacionalRounds)),
      act: (bloc) => bloc.add(
        const FixtureOpened(
          competitionId: 4616,
          phase: PhaseKey.regular,
          apiRound: 33,
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.stages, hasLength(36));
        expect(loadedMatches(bloc.state), hasLength(18));
      },
    );

    blocTest<CompetitionFixtureBloc, CompetitionFixtureState>(
      'Copa Argentina: cuartos (4) y semifinales (2)',
      build: () => buildBloc(FakeMatchRepository(copaRounds)),
      act: (bloc) async {
        bloc.add(
          const FixtureOpened(
            competitionId: 4500,
            phase: PhaseKey.unica,
            apiRound: 125,
            kind: StageKind.knockout,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.stage!.label, 'Cuartos de final');
        expect(loadedMatches(bloc.state), hasLength(4));
        bloc.add(const FixtureNextStageRequested());
      },
      verify: (bloc) {
        expect(bloc.state.stage!.label, 'Semifinales');
        expect(loadedMatches(bloc.state), hasLength(2));
      },
    );

    blocTest<CompetitionFixtureBloc, CompetitionFixtureState>(
      'sin red para la temporada: usa el año argentino actual',
      build: () => buildBloc(
        FakeMatchRepository(primeraRounds),
        competitions: FakeCompetitionRepository(
          failure: const NetworkFailure(
            issue: NetworkIssue.connection,
            detail: 'offline',
          ),
        ),
      ),
      act: (bloc) => bloc.add(const FixtureOpened(competitionId: 4406)),
      verify: (bloc) {
        expect(bloc.state.season, const Season(2026));
        // Sin puntero: primera etapa de la primera fase.
        expect(bloc.state.stage!.phase, PhaseKey.apertura);
        expect(bloc.state.stage!.label, 'Fecha 1');
      },
    );
  });

  group('navegación', () {
    blocTest<CompetitionFixtureBloc, CompetitionFixtureState>(
      'navegación rápida: solo queda la última fecha pedida, aunque las respuestas lleguen fuera de orden',
      build: () => buildBloc(
        FakeMatchRepository(
          primeraRounds,
          // La fecha 13 tarda más que la 15: si no se cancelara, la pisaría.
          delays: const {
            13: Duration(milliseconds: 60),
            14: Duration(milliseconds: 30),
            15: Duration(milliseconds: 5),
          },
        ),
      ),
      act: (bloc) async {
        bloc.add(const FixtureOpened(competitionId: 4406));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc
          ..add(const FixtureNextStageRequested())
          ..add(const FixtureNextStageRequested())
          ..add(const FixtureNextStageRequested());
      },
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        // Cada «siguiente» fija la etapa antes de cargar; `restartable`
        // cancela la carga anterior: la respuesta lenta de la fecha 13 no
        // pisa a la 15.
        final stage = bloc.state.stage!;
        expect(stage.phase, PhaseKey.clausura);
        expect(stage.label, 'Fecha 15');
        final matches = loadedMatches(bloc.state);
        expect(matches, hasLength(15));
        expect(matches.every((m) => m.apiRound == 15), isTrue);
        expect(
          matches.every(
            (m) => m.kickoff.argentinaDay == const CalendarDay(2026, 11, 1),
          ),
          isTrue,
        );
      },
    );

    blocTest<CompetitionFixtureBloc, CompetitionFixtureState>(
      'cambiar de fase mantiene el número de fecha',
      build: () => buildBloc(FakeMatchRepository(primeraRounds)),
      act: (bloc) async {
        bloc.add(const FixtureOpened(competitionId: 4406));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const FixturePhaseChanged(PhaseKey.apertura));
      },
      verify: (bloc) {
        expect(bloc.state.phase, PhaseKey.apertura);
        expect(bloc.state.stage!.apiRound, 12);
        expect(loadedMatches(bloc.state).first.kickoff.argentinaDay!.month, 3);
      },
    );

    test('después de cargar precarga la etapa siguiente', () async {
      final repo = FakeMatchRepository(primeraRounds);
      final bloc = buildBloc(repo);
      bloc.add(const FixtureOpened(competitionId: 4406));
      await bloc.stream.firstWhere((s) => s.content is FixtureLoaded);
      await Future<void>.delayed(Duration.zero);

      expect(repo.prefetched.map((q) => q.apiRound), [13]);
      await bloc.close();
    });
  });

  group('errores y casos vacíos', () {
    test('error con caché: datos visibles con refreshError', () async {
      final bloc = buildBloc(
        FakeMatchRepository(
          primeraRounds,
          refreshError: const NetworkFailure(
            issue: NetworkIssue.connection,
            detail: 'offline',
          ),
        ),
      );
      bloc.add(const FixtureOpened(competitionId: 4406));
      await bloc.stream.firstWhere((s) => s.content is FixtureLoaded);

      final content = bloc.state.content as FixtureLoaded;
      expect(content.refreshError, isA<NetworkFailure>());
      expect(content.matches.matches, hasLength(15));
      await bloc.close();
    });

    test('error sin caché: FixtureFailure', () async {
      final bloc = buildBloc(
        FakeMatchRepository(
          primeraRounds,
          failure: const RateLimitFailure(detail: '429'),
        ),
      );
      bloc.add(const FixtureOpened(competitionId: 4406));
      await bloc.stream.firstWhere((s) => s.content is FixtureFailure);

      expect(
        (bloc.state.content as FixtureFailure).failure,
        isA<RateLimitFailure>(),
      );
      await bloc.close();
    });

    blocTest<CompetitionFixtureBloc, CompetitionFixtureState>(
      'final de la Copa todavía sin partidos: vacío',
      build: () => buildBloc(FakeMatchRepository(copaRounds)),
      act: (bloc) => bloc.add(
        const FixtureOpened(
          competitionId: 4500,
          phase: PhaseKey.unica,
          apiRound: 200,
          kind: StageKind.knockout,
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.stage!.label, 'Final');
        expect(bloc.state.content, isA<FixtureEmpty>());
      },
    );

    blocTest<CompetitionFixtureBloc, CompetitionFixtureState>(
      'partido sin fase determinada: se cuenta y se puede ver aparte',
      build: () {
        final round12 = primeraRounds[12]!;
        final moved = rebuild(
          round12.first,
          kickoff: Kickoff(
            utc: DateTime.utc(2026, 6, 15, 20),
            argentinaDay: const CalendarDay(2026, 6, 15),
            certainty: KickoffCertainty.confirmed,
            evidence: KickoffEvidence.timestamp,
          ),
        );
        return buildBloc(
          FakeMatchRepository({
            ...primeraRounds,
            12: [moved, ...round12.skip(1)],
          }),
        );
      },
      act: (bloc) async {
        bloc.add(const FixtureOpened(competitionId: 4406));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.undeterminedInRound, 1);
        bloc.add(const FixturePhaseChanged(PhaseKey.undetermined));
      },
      verify: (bloc) {
        expect(bloc.state.phase, PhaseKey.undetermined);
        expect(bloc.state.phases, contains(PhaseKey.undetermined));
        expect(loadedMatches(bloc.state), hasLength(1));
      },
    );
  });

  test('catálogo: la Nacional 2026 tiene 36 fechas', () {
    expect(
      CompetitionCatalog.primeraNacional.expectedMinimumMatches(
        const Season(2026),
        36,
      ),
      18,
    );
  });

  group('Fase D3: copas internacionales', () {
    final libertadoresRounds = {
      for (final r in [1, 2, 3, 125, 150])
        r: fixtureMatches('eventsround_4501_r${r}_s2026'),
    };

    blocTest<CompetitionFixtureBloc, CompetitionFixtureState>(
      '`fase=previa&ronda=1` sin `etapa`: Fase 1 con sus 6 partidos',
      build: () => buildBloc(FakeMatchRepository(libertadoresRounds)),
      act: (bloc) => bloc.add(
        const FixtureOpened(
          competitionId: 4501,
          season: Season(2026),
          phase: PhaseKey.qualifying,
          apiRound: 1,
        ),
      ),
      verify: (bloc) {
        final state = bloc.state;
        expect(state.phases, [
          PhaseKey.qualifying,
          PhaseKey.groups,
          PhaseKey.knockoutStage,
        ]);
        expect(state.stage!.label, 'Fase 1');
        expect(state.stages.map((s) => s.label), [
          'Fase 1',
          'Fase 2',
          'Fase 3',
        ]);
        expect(loadedMatches(state), hasLength(6));
        // Los 16 de la Fecha 1 son de otra fase, no «sin fase».
        expect(state.undeterminedInRound, 0);
      },
    );

    blocTest<CompetitionFixtureBloc, CompetitionFixtureState>(
      'de las previas a los grupos: la Fecha 1, con los otros 16 de la ronda',
      build: () => buildBloc(FakeMatchRepository(libertadoresRounds)),
      act: (bloc) async {
        bloc.add(
          const FixtureOpened(
            competitionId: 4501,
            season: Season(2026),
            phase: PhaseKey.qualifying,
            apiRound: 1,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(const FixturePhaseChanged(PhaseKey.groups));
      },
      verify: (bloc) {
        expect(bloc.state.stage!.label, 'Fecha 1');
        expect(bloc.state.stage!.apiRound, 1);
        expect(loadedMatches(bloc.state), hasLength(16));
      },
    );

    blocTest<CompetitionFixtureBloc, CompetitionFixtureState>(
      'sin punteros (sin red ni caché): la etapa vigente por fecha, no la '
      'Fase 1 de febrero',
      build: () => buildBloc(
        FakeMatchRepository(libertadoresRounds),
        competitions: FakeCompetitionRepository(
          failure: const NetworkFailure(
            issue: NetworkIssue.timeout,
            detail: 'timeout',
          ),
        ),
      ),
      act: (bloc) => bloc.add(const FixtureOpened(competitionId: 4501)),
      verify: (bloc) {
        // 11/10/2026: las semifinales empiezan el 14.
        expect(bloc.state.phase, PhaseKey.knockoutStage);
        expect(bloc.state.stage!.label, 'Cuartos de final');
        expect(loadedMatches(bloc.state), hasLength(8));
      },
    );
  });
}
