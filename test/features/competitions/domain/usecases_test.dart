import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/result/data_result.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/competition.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/phase.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/stage.dart';
import 'package:futbol_argentino/features/competitions/domain/repositories/competition_repository.dart';
import 'package:futbol_argentino/features/competitions/domain/services/round_navigator.dart';
import 'package:futbol_argentino/features/competitions/domain/usecases/resolve_current_stage.dart';
import 'package:futbol_argentino/features/competitions/domain/usecases/watch_stage_matches.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';

import '../../../helpers/fixture_matches.dart';

final fetchedAt = DateTime.utc(2026, 10, 11, 20, 35);

/// Repositorio en memoria con rondas reales grabadas.
class FakeMatchRepository implements MatchRepository {
  FakeMatchRepository(this.rounds, {this.refreshError});

  final Map<int, List<Match>> rounds;
  final Failure? refreshError;
  final queries = <RoundQuery>[];

  @override
  Stream<DataResult<List<Match>>> watchRound(
    RoundQuery query, {
    bool forceRefresh = false,
  }) {
    queries.add(query);
    return Stream.value(
      DataResult(
        data: rounds[query.apiRound] ?? const [],
        origin: refreshError == null ? DataOrigin.remote : DataOrigin.cache,
        fetchedAt: fetchedAt,
        refreshError: refreshError,
      ),
    );
  }

  @override
  Future<DataResult<Match>> getMatch(
    int matchId, {
    bool forceRefresh = false,
  }) => throw UnimplementedError();
}

class FakeCompetitionRepository implements CompetitionRepository {
  FakeCompetitionRepository({this.pointers, this.failure});

  final SchedulePointers? pointers;
  final Failure? failure;

  @override
  Future<DataResult<Competition>> getCompetition(int competitionId) =>
      throw UnimplementedError();

  @override
  Future<DataResult<SchedulePointers>> getSchedulePointers(
    int competitionId, {
    bool forceRefresh = false,
  }) async {
    if (failure != null) throw failure!;
    return DataResult(
      data: pointers!,
      origin: DataOrigin.remote,
      fetchedAt: fetchedAt,
    );
  }
}

Stage stageOf(
  CompetitionDefinition definition,
  PhaseKey phase,
  int apiRound, {
  StageKind kind = StageKind.regular,
}) => RoundNavigator.stagesFor(
  definition,
  const Season(2026),
  phase,
).singleWhere((s) => s.apiRound == apiRound && s.kind == kind);

void main() {
  const primera = CompetitionCatalog.primeraDivision;
  final repository = FakeMatchRepository({
    12: fixtureMatches('eventsround_4406_r12_s2026'),
    16: fixtureMatches('eventsround_4406_r16_s2026'),
  });
  final watch = WatchStageMatches(repository);

  group('WatchStageMatches', () {
    test('Apertura fecha 12: los 15 partidos de marzo', () async {
      final result = await watch(
        primera,
        stageOf(primera, PhaseKey.apertura, 12),
      ).first;

      expect(result.data.matches, hasLength(15));
      expect(
        result.data.matches.every((m) => m.kickoff.argentinaDay!.month == 3),
        isTrue,
      );
      expect(result.data.undeterminedInRound, 0);
    });

    test('Clausura fecha 12: los 15 partidos de octubre, ordenados', () async {
      final result = await watch(
        primera,
        stageOf(primera, PhaseKey.clausura, 12),
      ).first;

      final days = result.data.matches.map((m) => m.kickoff.argentinaDay!);
      expect(days, hasLength(15));
      expect(days.every((d) => d.month == 10), isTrue);
      expect(days.toList(), [...days]..sort());
    });

    test('octavos del Apertura: 8 partidos de la ronda 16', () async {
      final result = await watch(
        primera,
        stageOf(primera, PhaseKey.apertura, 16, kind: StageKind.knockout),
      ).first;

      expect(result.data.matches, hasLength(8));
      expect(result.data.stage.label, 'Octavos de final');
    });

    test('consulta la ronda con la cantidad mínima esperada', () async {
      await watch(primera, stageOf(primera, PhaseKey.apertura, 12)).first;

      expect(
        repository.queries.last,
        const RoundQuery(competitionId: 4406, season: '2026', apiRound: 12),
      );
      expect(repository.queries.last.expectedMinimum, 15);
    });

    test('conserva el origen y el error de actualización', () async {
      final offline = WatchStageMatches(
        FakeMatchRepository(
          {12: fixtureMatches('eventsround_4406_r12_s2026')},
          refreshError: const NetworkFailure(
            issue: NetworkIssue.connection,
            detail: 'sin conexión',
          ),
        ),
      );

      final result = await offline(
        primera,
        stageOf(primera, PhaseKey.clausura, 12),
      ).first;

      expect(result.origin, DataOrigin.cache);
      expect(result.refreshError, isA<NetworkFailure>());
      expect(result.data.matches, hasLength(15));
    });
  });

  group('ResolveCurrentStage', () {
    test(
      'Primera: el próximo partido real (fecha 12, octubre) → Clausura fecha 12',
      () async {
        final next = fixtureMatches('eventsnextleague_4406').single;
        final resolve = ResolveCurrentStage(
          FakeCompetitionRepository(pointers: SchedulePointers(next: next)),
        );

        final stage = await resolve(primera, const Season(2026));

        expect(stage!.phase, PhaseKey.clausura);
        expect(stage.apiRound, 12);
        expect(stage.label, 'Fecha 12');
      },
    );

    test('Primera Nacional: ronda del próximo partido real', () async {
      final next = fixtureMatches('eventsnextleague_4616').single;
      final resolve = ResolveCurrentStage(
        FakeCompetitionRepository(pointers: SchedulePointers(next: next)),
      );

      final stage = await resolve(
        CompetitionCatalog.primeraNacional,
        const Season(2026),
      );

      expect(stage!.phase, PhaseKey.regular);
      expect(stage.apiRound, next.apiRound);
    });

    test('Copa: sin próximo, usa el último jugado (cuartos)', () async {
      final last = fixtureMatches('eventsround_4500_r125_s2026').first;
      final resolve = ResolveCurrentStage(
        FakeCompetitionRepository(pointers: SchedulePointers(last: last)),
      );

      final stage = await resolve(
        CompetitionCatalog.copaArgentina,
        const Season(2026),
      );

      expect(stage!.label, 'Cuartos de final');
    });

    test('sin red ni caché: primera etapa de la primera fase', () async {
      final resolve = ResolveCurrentStage(
        FakeCompetitionRepository(
          failure: const NetworkFailure(
            issue: NetworkIssue.timeout,
            detail: 'timeout',
          ),
        ),
      );

      final stage = await resolve(primera, const Season(2026));

      expect(stage!.phase, PhaseKey.apertura);
      expect(stage.label, 'Fecha 1');
    });

    test('el puntero es de otra temporada: primera etapa', () async {
      final next = fixtureMatches('eventsnextleague_4406').single;
      final resolve = ResolveCurrentStage(
        FakeCompetitionRepository(pointers: SchedulePointers(next: next)),
      );

      final stage = await resolve(primera, const Season(2025));

      expect(stage!.season, const Season(2025));
      expect(stage.label, 'Fecha 1');
    });
  });
}
