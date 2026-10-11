import '../entities/api_query_result.dart';

abstract class MatchRepository {
  /// Consulta los partidos de una fecha.
  ///
  /// Lanza `ApiFailure` si la consulta falla.
  Future<ApiQueryResult> fetchRound({
    required int leagueId,
    required int round,
    required int season,
  });
}
