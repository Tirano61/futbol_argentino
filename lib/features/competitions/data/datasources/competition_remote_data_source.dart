import '../../../../core/network/json_envelope.dart';
import '../../../../core/network/thesportsdb_client.dart';
import '../../../matches/data/models/event_dto.dart';
import '../models/league_dto.dart';

/// Consultas de competiciones a TheSportsDB. Lanza `ApiException` o
/// `JsonShapeException`; el repositorio las traduce a `Failure`.
class CompetitionRemoteDataSource {
  CompetitionRemoteDataSource(this._client);

  final TheSportsDbClient _client;

  /// `lookupleague.php`, o `null` si la API no la tiene.
  Future<LeagueDto?> fetchLeague(int competitionId) async {
    final response = await _client.getJson('lookupleague.php', {
      'id': '$competitionId',
    });
    final leagues = JsonEnvelope.records(response.json, 'leagues');
    return leagues.isEmpty ? null : LeagueDto.fromJson(leagues.first);
  }

  /// `eventsnextleague.php` (1 resultado con la clave gratuita).
  Future<EventDto?> fetchNextEvent(int competitionId) =>
      _firstEvent('eventsnextleague.php', competitionId);

  /// `eventspastleague.php` (1 resultado con la clave gratuita).
  Future<EventDto?> fetchLastEvent(int competitionId) =>
      _firstEvent('eventspastleague.php', competitionId);

  Future<EventDto?> _firstEvent(String endpoint, int competitionId) async {
    final response = await _client.getJson(endpoint, {'id': '$competitionId'});
    final events = JsonEnvelope.records(response.json, 'events');
    return events.isEmpty ? null : EventDto.fromJson(events.first);
  }
}
