import 'football_match.dart';

/// Resultado de una consulta exitosa (HTTP 2xx y JSON válido).
class ApiQueryResult {
  const ApiQueryResult({
    required this.statusCode,
    required this.elapsedMs,
    required this.matches,
    required this.prettyJson,
  });

  final int statusCode;
  final int elapsedMs;
  final List<FootballMatch> matches;
  final String prettyJson;
}
