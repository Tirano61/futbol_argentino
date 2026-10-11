import 'package:futbol_argentino/features/matches/domain/entities/kickoff.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match_status.dart';
import 'package:futbol_argentino/features/matches/domain/entities/score.dart';
import 'package:futbol_argentino/features/matches/domain/entities/team_ref.dart';
import 'package:futbol_argentino/features/matches/domain/services/kickoff_resolver.dart';
import 'package:futbol_argentino/features/matches/domain/services/match_status_mapper.dart';

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

/// Convierte un evento real en [Match] para tests de dominio. Es una versión
/// mínima, solo para tests: en la app lo hace `EventMapper` (Fase 3).
Match matchFromEvent(
  Map<String, dynamic> e, {
  DateTime? seenAt,
  Kickoff? kickoff,
  int? apiRound,
}) {
  int? toInt(Object? v) => v == null ? null : int.tryParse('$v'.trim());
  final home = toInt(e['intHomeScore']);
  final away = toInt(e['intAwayScore']);
  return Match(
    id: toInt(e['idEvent'])!,
    competitionId: toInt(e['idLeague'])!,
    competitionName: e['strLeague'] as String,
    season: e['strSeason'] as String,
    apiRound: apiRound ?? toInt(e['intRound'])!,
    home: TeamRef(
      id: toInt(e['idHomeTeam'])!,
      name: e['strHomeTeam'] as String,
      badgeUrl: e['strHomeTeamBadge'] as String?,
    ),
    away: TeamRef(
      id: toInt(e['idAwayTeam'])!,
      name: e['strAwayTeam'] as String,
      badgeUrl: e['strAwayTeamBadge'] as String?,
    ),
    kickoff: kickoff ?? resolveEvent(e),
    status: MatchStatusMapper.fromApi(
      e['strStatus'] as String?,
      postponed: e['strPostponed'] as String?,
    ),
    score: home != null && away != null ? Score(home: home, away: away) : null,
    venue: e['strVenue'] as String?,
    lastSeenAt: seenAt ?? defaultSeenAt,
  );
}

/// Todos los partidos de una respuesta grabada.
List<Match> fixtureMatches(String name, {DateTime? seenAt}) => [
  for (final e in fixtureEvents(name)) matchFromEvent(e, seenAt: seenAt),
];

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
