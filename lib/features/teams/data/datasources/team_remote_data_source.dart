import '../../../../core/network/json_envelope.dart';
import '../../../../core/network/thesportsdb_client.dart';
import '../models/team_dto.dart';

/// Consultas de equipos a TheSportsDB. Lanza `ApiException` o
/// `JsonShapeException`; el repositorio las traduce a `Failure`.
class TeamRemoteDataSource {
  TeamRemoteDataSource(this._client);

  final TheSportsDbClient _client;

  /// `lookupteam.php`, o `null` si la API no lo tiene (o devuelve otro).
  Future<TeamDto?> fetchTeam(int id) async {
    final response = await _client.getJson('lookupteam.php', {'id': '$id'});
    final teams = JsonEnvelope.records(response.json, 'teams');
    if (teams.isEmpty) return null;
    final dto = TeamDto.fromJson(teams.first);
    return dto.idTeam == id ? dto : null;
  }

  /// `searchteams.php` (con la clave gratuita devuelve como mucho 1).
  Future<List<TeamDto>> search(String name) async {
    final response = await _client.getJson('searchteams.php', {'t': name});
    return [
      for (final t in JsonEnvelope.records(response.json, 'teams'))
        TeamDto.fromJson(t),
    ];
  }
}
