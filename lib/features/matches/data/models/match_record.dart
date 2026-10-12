import '../../../../core/time/calendar_day.dart';
import '../../domain/entities/kickoff.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/match_status.dart';
import '../../domain/entities/score.dart';
import '../../domain/entities/team_ref.dart';

/// Un equipo visto en un partido guardado.
typedef TeamSighting = ({
  TeamRef team,
  int competitionId,
  String season,
  DateTime seenAt,
});

/// Forma en que se guarda un [Match] en la base local. Conserva todo lo que
/// produjo el merge (certeza del horario, ronda anterior, membresía…), que
/// no se puede reconstruir desde el JSON de la API.
abstract final class MatchRecord {
  static const schemaVersion = 1;

  static Map<String, Object?> toMap(Match m) => {
    'v': schemaVersion,
    'id': m.id,
    'competitionId': m.competitionId,
    'competitionName': m.competitionName,
    'season': m.season,
    'apiRound': m.apiRound,
    'home': _team(m.home),
    'away': _team(m.away),
    // Para buscar los partidos de un equipo.
    'teamIds': [m.home.id, m.away.id],
    'kickoff': {
      'utc': m.kickoff.utc?.toIso8601String(),
      'day': m.kickoff.argentinaDay?.toString(),
      'certainty': m.kickoff.certainty.name,
      'evidence': m.kickoff.evidence.name,
    },
    'status': {
      'kind': m.status.kind.name,
      'decidedBy': m.status.decidedBy.name,
      'raw': m.status.raw,
    },
    'score': m.score == null ? null : [m.score!.home, m.score!.away],
    'venue': m.venue,
    'thumbUrl': m.thumbUrl,
    'videoUrl': m.videoUrl,
    'previousKickoffUtc': m.previousKickoffUtc?.toIso8601String(),
    'previousApiRound': m.previousApiRound,
    'membership': m.membership.name,
    'lastSeenAt': m.lastSeenAt.toIso8601String(),
  };

  static Match fromMap(Map<String, Object?> map) {
    final kickoff = map['kickoff']! as Map<String, Object?>;
    final status = map['status']! as Map<String, Object?>;
    final score = map['score'] as List<Object?>?;
    return Match(
      id: map['id']! as int,
      competitionId: map['competitionId']! as int,
      competitionName: map['competitionName']! as String,
      season: map['season']! as String,
      apiRound: map['apiRound']! as int,
      home: _teamFrom(map['home']! as Map<String, Object?>),
      away: _teamFrom(map['away']! as Map<String, Object?>),
      kickoff: Kickoff(
        utc: _date(kickoff['utc']),
        argentinaDay: CalendarDay.tryParse(kickoff['day'] as String?),
        certainty: KickoffCertainty.values.byName(
          kickoff['certainty']! as String,
        ),
        evidence: KickoffEvidence.values.byName(kickoff['evidence']! as String),
      ),
      status: MatchStatus(
        kind: MatchStatusKind.values.byName(status['kind']! as String),
        decidedBy: MatchDecision.values.byName(status['decidedBy']! as String),
        raw: status['raw'] as String?,
      ),
      score: score == null
          ? null
          : Score(home: score[0]! as int, away: score[1]! as int),
      venue: map['venue'] as String?,
      thumbUrl: map['thumbUrl'] as String?,
      videoUrl: map['videoUrl'] as String?,
      previousKickoffUtc: _date(map['previousKickoffUtc']),
      previousApiRound: map['previousApiRound'] as int?,
      membership: MatchMembership.values.byName(map['membership']! as String),
      lastSeenAt: _date(map['lastSeenAt'])!,
    );
  }

  /// Los dos equipos de un partido guardado, sin reconstruir el partido
  /// (para el índice de equipos). Vacío si la API lo dio de baja.
  static List<TeamSighting> sightingsFromMap(Map<String, Object?> map) {
    if (map['membership'] == MatchMembership.removed.name) return const [];
    final competitionId = map['competitionId']! as int;
    final season = map['season']! as String;
    final seenAt = _date(map['lastSeenAt'])!;
    return [
      for (final side in ['home', 'away'])
        (
          team: _teamFrom(map[side]! as Map<String, Object?>),
          competitionId: competitionId,
          season: season,
          seenAt: seenAt,
        ),
    ];
  }

  static Map<String, Object?> _team(TeamRef t) => {
    'id': t.id,
    'name': t.name,
    'badgeUrl': t.badgeUrl,
  };

  static TeamRef _teamFrom(Map<String, Object?> map) => TeamRef(
    id: map['id']! as int,
    name: map['name']! as String,
    badgeUrl: map['badgeUrl'] as String?,
  );

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value).toUtc() : null;
}
