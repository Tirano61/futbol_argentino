import 'dart:convert';

import '../../domain/entities/api_query_result.dart';
import '../../domain/entities/football_match.dart';
import '../../domain/errors/api_failure.dart';
import '../../domain/repositories/match_repository.dart';
import '../models/event_model.dart';
import '../services/thesportsdb_service.dart';

class MatchRepositoryImpl implements MatchRepository {
  MatchRepositoryImpl(this._service);

  final TheSportsDbService _service;

  @override
  Future<ApiQueryResult> fetchRound({
    required int leagueId,
    required int round,
    required int season,
  }) async {
    final raw = await _service.getEventsRound(
      leagueId: leagueId,
      round: round,
      season: season,
    );

    if (raw.statusCode < 200 || raw.statusCode >= 300) {
      throw ApiFailure(
        type: ApiFailureType.http,
        message:
            'El servidor respondió HTTP ${raw.statusCode}'
            '${raw.reasonPhrase != null ? ' ${raw.reasonPhrase}' : ''}',
        statusCode: raw.statusCode,
        elapsedMs: raw.elapsedMs,
        rawBody: utf8.decode(raw.bodyBytes, allowMalformed: true),
      );
    }

    Never formatError(String message) => throw ApiFailure(
      type: ApiFailureType.format,
      message: message,
      statusCode: raw.statusCode,
      elapsedMs: raw.elapsedMs,
      rawBody: utf8.decode(raw.bodyBytes, allowMalformed: true),
    );

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(raw.bodyBytes));
    } on FormatException catch (e) {
      formatError(
        'FormatException: ${e.message}'
        '${e.offset != null ? ' (posición ${e.offset})' : ''}',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      formatError(
        'Se esperaba un objeto JSON en la raíz y llegó ${decoded.runtimeType}',
      );
    }

    final events = decoded['events'];
    final List<FootballMatch> matches;
    if (events == null) {
      // Respuesta válida sin partidos (TheSportsDB devuelve "events": null).
      matches = const [];
    } else if (events is List) {
      matches = [
        for (final (index, event) in events.indexed)
          if (event is Map<String, dynamic>)
            EventModel.fromJson(event).toEntity()
          else
            formatError(
              'events[$index] no es un objeto JSON (${event.runtimeType})',
            ),
      ];
    } else {
      formatError('"events" no es una lista (${events.runtimeType})');
    }

    return ApiQueryResult(
      statusCode: raw.statusCode,
      elapsedMs: raw.elapsedMs,
      matches: matches,
      prettyJson: const JsonEncoder.withIndent('  ').convert(decoded),
    );
  }
}
