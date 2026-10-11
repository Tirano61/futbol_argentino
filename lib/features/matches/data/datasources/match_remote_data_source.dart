import '../../../../core/network/json_envelope.dart';
import '../../../../core/network/thesportsdb_client.dart';
import '../models/event_dto.dart';

/// Consultas de partidos a TheSportsDB. Lanza `ApiException` o
/// `JsonShapeException`; el repositorio las traduce a `Failure`.
class MatchRemoteDataSource {
  MatchRemoteDataSource(this._client);

  final TheSportsDbClient _client;

  /// `eventsround.php`: todos los partidos de una ronda (sin tope observado).
  Future<List<EventDto>> fetchRound({
    required int competitionId,
    required String season,
    required int apiRound,
  }) async {
    final response = await _client.getJson('eventsround.php', {
      'id': '$competitionId',
      'r': '$apiRound',
      's': season,
    });
    return [
      for (final e in JsonEnvelope.records(response.json, 'events'))
        EventDto.fromJson(e),
    ];
  }

  /// `lookupevent.php`: un partido, o `null` si la API no lo tiene (o
  /// devuelve otro evento).
  Future<EventDto?> fetchEvent(int id) async {
    final response = await _client.getJson('lookupevent.php', {'id': '$id'});
    final events = JsonEnvelope.records(response.json, 'events');
    if (events.isEmpty) return null;
    final dto = EventDto.fromJson(events.first);
    return dto.idEvent == id ? dto : null;
  }
}
