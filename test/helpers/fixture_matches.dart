import 'package:futbol_argentino/features/matches/data/mappers/event_mapper.dart';
import 'package:futbol_argentino/features/matches/data/models/event_dto.dart';
import 'package:futbol_argentino/features/matches/domain/entities/kickoff.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match_status.dart';
import 'package:futbol_argentino/features/matches/domain/entities/score.dart';
import 'package:futbol_argentino/features/matches/domain/entities/team_ref.dart';
import 'package:futbol_argentino/features/matches/domain/services/kickoff_resolver.dart';

import 'fixtures.dart';

/// Resuelve el horario de un evento real con `KickoffResolver`.
Kickoff resolveEvent(Map<String, dynamic> e) => KickoffResolver.resolve(
  timestamp: e['strTimestamp'] as String?,
  date: e['dateEvent'] as String?,
  time: e['strTime'] as String?,
  localTime: e['strTimeLocal'] as String?,
  localDate: e['dateEventLocal'] as String?,
);

final defaultSeenAt = DateTime.utc(2026, 10, 11, 20, 35);

/// Convierte un evento real en [Match] con el `EventMapper` de la app.
/// [kickoff] y [apiRound] permiten variantes para tests.
Match matchFromEvent(
  Map<String, dynamic> e, {
  DateTime? seenAt,
  Kickoff? kickoff,
  int? apiRound,
}) {
  final match = EventMapper.toEntity(
    EventDto.fromJson(e),
    seenAt: seenAt ?? defaultSeenAt,
  )!;
  return kickoff == null && apiRound == null
      ? match
      : rebuild(match, kickoff: kickoff, apiRound: apiRound);
}

/// Todos los partidos de una respuesta grabada.
List<Match> fixtureMatches(String name, {DateTime? seenAt}) => [
  for (final e in fixtureEvents(name)) matchFromEvent(e, seenAt: seenAt),
];

/// El partido de una respuesta grabada de `eventslast` (clave `results`).
Match recordedLastMatch(String name) => matchFromEvent(
  (fixtureJson(name)['results'] as List).single as Map<String, dynamic>,
);

/// Copia de [m] con campos cambiados (solo para tests).
Match rebuild(
  Match m, {
  Kickoff? kickoff,
  Score? score,
  bool clearScore = false,
  MatchStatus? status,
  int? apiRound,
  TeamRef? home,
  DateTime? lastSeenAt,
  MatchMembership? membership,
}) => Match(
  id: m.id,
  competitionId: m.competitionId,
  competitionName: m.competitionName,
  season: m.season,
  apiRound: apiRound ?? m.apiRound,
  home: home ?? m.home,
  away: m.away,
  kickoff: kickoff ?? m.kickoff,
  status: status ?? m.status,
  score: clearScore ? null : (score ?? m.score),
  venue: m.venue,
  thumbUrl: m.thumbUrl,
  videoUrl: m.videoUrl,
  previousKickoffUtc: m.previousKickoffUtc,
  previousApiRound: m.previousApiRound,
  membership: membership ?? m.membership,
  lastSeenAt: lastSeenAt ?? m.lastSeenAt,
);
