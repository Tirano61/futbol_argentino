import '../../../competitions/domain/catalog/competition_catalog.dart';
import '../entities/team_summary.dart';
import '../repositories/team_repository.dart';
import '../services/team_index.dart';

/// Respaldo cuando el índice local no encuentra nada: `searchteams`
/// (equipos de fútbol de Argentina). Las competiciones son las que informa
/// la API dentro del catálogo.
class SearchTeamsOnline {
  const SearchTeamsOnline(this._teams);

  final TeamRepository _teams;

  /// Si [query] alcanza para buscar en línea ([TeamIndex.allowsOnlineSearch]).
  bool accepts(String query) => TeamIndex.allowsOnlineSearch(query);

  /// Lanza `Failure` si la consulta falla.
  Future<List<TeamSummary>> call(String query) async => [
    for (final team in await _teams.searchOnline(query))
      TeamSummary(
        team: team.ref,
        competitionIds: [
          for (final id in team.leagueIds)
            if (CompetitionCatalog.byId(id) != null) id,
        ],
      ),
  ];
}
