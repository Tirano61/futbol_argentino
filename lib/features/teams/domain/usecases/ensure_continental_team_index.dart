import '../../../../core/error/failure.dart';
import '../../../../core/sync/sync_scheduler.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../competitions/domain/catalog/competition_catalog.dart';
import '../../../competitions/domain/entities/phase.dart';
import '../../../competitions/domain/entities/season.dart';
import '../../../matches/domain/repositories/match_repository.dart';

/// Arranque bajo demanda del buscador para las copas internacionales (Fase
/// D6): la Fecha 1 de grupos de cada copa del catálogo trae a sus 32
/// equipos. Una petición por copa (P1) la primera vez; ninguna mientras
/// esas rondas estén vigentes. No es la primera ronda de la temporada
/// ([EnsureTeamIndex.firstRound] tomaría las fases previas).
///
/// La temporada es el año argentino si su fase de grupos ya empezó; si no
/// (enero a marzo), la anterior.
class EnsureContinentalTeamIndex {
  const EnsureContinentalTeamIndex(
    this._matches, {
    List<CompetitionDefinition> catalog = CompetitionCatalog.all,
  }) : _catalog = catalog;

  final MatchRepository _matches;
  final List<CompetitionDefinition> _catalog;

  /// La Fecha 1 de grupos de cada copa; vacía si ninguna tiene una que ya
  /// haya empezado.
  List<RoundQuery> queries({required DateTime now}) {
    final today = ArgentinaTime.dayOf(now);
    final current = Season(today.year);
    final result = <RoundQuery>[];
    for (final d in _catalog) {
      final rules = d.rules;
      if (rules is! ContinentalCupRules) continue;
      for (final season in [current, current.previous]) {
        final first = rules
            .stagesOf(season)
            .where((s) => s.phase == PhaseKey.groups)
            .firstOrNull;
        if (first == null || first.from?.isAfter(today) != false) continue;
        result.add(
          RoundQuery(
            competitionId: d.id,
            season: season.apiValue,
            apiRound: first.apiRound,
            expectedMinimum: d.expectedMinimumMatches(season, first.apiRound),
          ),
        );
        break;
      }
    }
    return result;
  }

  /// Las rondas ya están guardadas: no hace falta ofrecer el arranque.
  Future<bool> isDone({required DateTime now}) async {
    for (final query in queries(now: now)) {
      if ((await _matches.storedRound(query)).isEmpty) return false;
    }
    return true;
  }

  /// Devuelve el primer error, o `null` si todas las rondas están al día.
  Future<Failure?> call({
    required DateTime now,
    SyncPriority priority = SyncPriority.context,
  }) async {
    final failures = await Future.wait([
      for (final query in queries(now: now)) _ensure(query, priority),
    ]);
    return failures.nonNulls.firstOrNull;
  }

  Future<Failure?> _ensure(RoundQuery query, SyncPriority priority) async {
    try {
      await _matches.syncRound(query, priority: priority);
      return null;
    } on Failure catch (failure) {
      return failure;
    }
  }
}
