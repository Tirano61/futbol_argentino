import '../../../../core/error/failure.dart';
import '../../../../core/sync/sync_scheduler.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../competitions/domain/catalog/competition_catalog.dart';
import '../../../competitions/domain/entities/season.dart';
import '../../../competitions/domain/services/round_navigator.dart';
import '../../../matches/domain/repositories/match_repository.dart';

/// Completa el índice local de equipos: la primera etapa de cada
/// competición del catálogo marcada con `inTeamIndex` (Primera fecha 1,
/// Nacional fecha 1, Copa 32avos) trae a todos sus equipos de la
/// temporada. 3 peticiones en frío; ninguna mientras esas rondas estén
/// vigentes (terminadas: 30 días).
///
/// La temporada es el año argentino. Si su primera etapa todavía no tiene
/// partidos (p. ej. en enero), se usa la de la temporada anterior.
class EnsureTeamIndex {
  const EnsureTeamIndex(
    this._matches, {
    List<CompetitionDefinition> catalog = CompetitionCatalog.all,
  }) : _catalog = catalog;

  final MatchRepository _matches;
  final List<CompetitionDefinition> _catalog;

  /// Devuelve el primer error, o `null` si todas las rondas están al día.
  Future<Failure?> call({
    required DateTime now,
    SyncPriority priority = SyncPriority.context,
  }) async {
    final season = Season(ArgentinaTime.dayOf(now).year);
    final failures = await Future.wait([
      for (final d in _catalog)
        if (d.inTeamIndex) _ensure(d, season, priority),
    ]);
    return failures.nonNulls.firstOrNull;
  }

  /// Primera ronda de [definition] en [season].
  static RoundQuery firstRound(
    CompetitionDefinition definition,
    Season season,
  ) {
    // Sin cantidad de fechas verificada, alcanza con saber que hay fecha 1.
    final stage = RoundNavigator.stagesFor(
      definition,
      season,
      definition.phases.first,
      knownMaxRound: 1,
    ).first;
    return RoundQuery(
      competitionId: definition.id,
      season: season.apiValue,
      apiRound: stage.apiRound,
      expectedMinimum: definition.expectedMinimumMatches(stage.apiRound),
    );
  }

  Future<Failure?> _ensure(
    CompetitionDefinition definition,
    Season season,
    SyncPriority priority,
  ) async {
    try {
      final query = firstRound(definition, season);
      await _matches.syncRound(query, priority: priority);
      if ((await _matches.storedRound(query)).isEmpty) {
        await _matches.syncRound(
          firstRound(definition, season.previous),
          priority: priority,
        );
      }
      return null;
    } on Failure catch (failure) {
      return failure;
    }
  }
}
