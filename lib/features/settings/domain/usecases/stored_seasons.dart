import '../../../../core/time/argentina_time.dart';
import '../../../competitions/domain/catalog/competition_catalog.dart';
import '../../../competitions/domain/entities/season.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../entities/stored_season.dart';

/// Temporadas guardadas por competición (orden del catálogo, la más
/// reciente primero), sin red.
class GetStoredSeasons {
  const GetStoredSeasons(
    this._matches, {
    List<CompetitionDefinition> catalog = CompetitionCatalog.all,
  }) : _catalog = catalog;

  final MatchRepository _matches;
  final List<CompetitionDefinition> _catalog;

  Future<List<StoredSeason>> call({required DateTime now}) async {
    final current = currentSeason(now);
    final seasons = [
      for (final s in await _matches.storedSeasons())
        StoredSeason(
          competitionId: s.competitionId,
          competitionName:
              _definition(s.competitionId)?.name ?? s.competitionName,
          season: s.season,
          matchCount: s.matchCount,
          isCurrent: isCurrentOrLater(s.season, current),
        ),
    ];
    int order(StoredSeason s) {
      final index = _catalog.indexWhere((d) => d.id == s.competitionId);
      return index < 0 ? _catalog.length : index;
    }

    return seasons..sort(
      (a, b) => order(a) != order(b)
          ? order(a) - order(b)
          : a.competitionId != b.competitionId
          ? a.competitionId - b.competitionId
          : b.season.compareTo(a.season),
    );
  }

  CompetitionDefinition? _definition(int id) =>
      _catalog.where((d) => d.id == id).firstOrNull;

  /// La del año argentino.
  static Season currentSeason(DateTime now) =>
      Season(ArgentinaTime.dayOf(now).year);

  /// Las temporadas que no son `YYYY` se consideran anteriores.
  static bool isCurrentOrLater(String season, Season current) {
    final parsed = Season.tryParse(season);
    return parsed != null && parsed.compareTo(current) >= 0;
  }
}

/// Borra los partidos guardados de las temporadas elegidas (limpieza
/// manual). La temporada actual no se puede borrar; los favoritos nunca se
/// tocan.
class DeleteStoredSeasons {
  const DeleteStoredSeasons(this._matches);

  final MatchRepository _matches;

  /// Devuelve cuántos partidos se borraron.
  ///
  /// Lanza [ArgumentError] si alguna es la temporada actual (o posterior),
  /// sin borrar nada.
  Future<int> call(List<StoredSeason> seasons, {required DateTime now}) async {
    final current = GetStoredSeasons.currentSeason(now);
    final blocked = [
      for (final s in seasons)
        if (GetStoredSeasons.isCurrentOrLater(s.season, current)) s.key,
    ];
    if (blocked.isNotEmpty) {
      throw ArgumentError.value(
        blocked,
        'seasons',
        'La temporada actual no se puede borrar',
      );
    }
    var deleted = 0;
    for (final s in seasons) {
      deleted += await _matches.deleteSeason(s.competitionId, s.season);
    }
    return deleted;
  }
}
