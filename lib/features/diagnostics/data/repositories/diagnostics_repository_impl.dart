import 'dart:convert';

import '../../../../core/error/failure.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/json_envelope.dart';
import '../../../../core/network/thesportsdb_client.dart';
import '../../domain/entities/api_query_result.dart';
import '../../domain/repositories/diagnostics_repository.dart';
import '../models/event_model.dart';

class DiagnosticsRepositoryImpl implements DiagnosticsRepository {
  DiagnosticsRepositoryImpl(this._client);

  final TheSportsDbClient _client;

  @override
  Future<ApiQueryResult> fetchRound({
    required int leagueId,
    required int round,
    required int season,
  }) async {
    final ApiResponse response;
    try {
      response = await _client.getJson('eventsround.php', {
        'id': '$leagueId',
        'r': '$round',
        's': '$season',
      });
    } on ApiException catch (e) {
      throw e.toFailure();
    }

    final prettyJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(response.json);

    final List<Map<String, dynamic>> events;
    try {
      events = JsonEnvelope.records(response.json, 'events');
    } on JsonShapeException catch (e) {
      throw FormatFailure(
        detail: e.message,
        statusCode: response.statusCode,
        elapsed: response.elapsed,
        responseBody: prettyJson,
      );
    }

    return ApiQueryResult(
      statusCode: response.statusCode,
      elapsedMs: response.elapsed.inMilliseconds,
      matches: [for (final e in events) EventModel.fromJson(e).toEntity()],
      prettyJson: prettyJson,
    );
  }
}
