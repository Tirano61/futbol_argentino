import '../entities/api_query_result.dart';

abstract class DiagnosticsRepository {
  /// Consulta los partidos de una fecha.
  ///
  /// Lanza `Failure` si la consulta falla.
  Future<ApiQueryResult> fetchRound({
    required int leagueId,
    required int round,
    required int season,
  });
}
