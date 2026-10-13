import '../../../matches/data/models/match_record.dart';
import '../../domain/entities/team.dart';
import '../../domain/entities/team_pointers.dart';

/// Forma en que se guarda un [Team] en la base local (store `teams`).
abstract final class TeamRecord {
  static const schemaVersion = 1;

  static Map<String, Object?> toMap(Team t) => {
    'v': schemaVersion,
    'id': t.id,
    'name': t.name,
    'alternateNames': t.alternateNames,
    'badgeUrl': t.badgeUrl,
    'stadium': t.stadium,
    'location': t.location,
    'leagueIds': t.leagueIds,
  };

  static Team fromMap(Map<String, Object?> map) => Team(
    id: map['id']! as int,
    name: map['name']! as String,
    alternateNames: [
      for (final n in map['alternateNames']! as List<Object?>) n! as String,
    ],
    badgeUrl: map['badgeUrl'] as String?,
    stadium: map['stadium'] as String?,
    location: map['location'] as String?,
    leagueIds: [
      for (final id in map['leagueIds']! as List<Object?>) id! as int,
    ],
  );
}

/// Forma en que se guardan los [TeamPointers] (store `team_pointers`).
abstract final class TeamPointersRecord {
  static Map<String, Object?> toMap(TeamPointers p) => {
    'next': p.next == null ? null : MatchRecord.toMap(p.next!),
    'last': p.last == null ? null : MatchRecord.toMap(p.last!),
  };

  static TeamPointers fromMap(Map<String, Object?> map) {
    final next = map['next'] as Map<String, Object?>?;
    final last = map['last'] as Map<String, Object?>?;
    return TeamPointers(
      next: next == null ? null : MatchRecord.fromMap(next),
      last: last == null ? null : MatchRecord.fromMap(last),
    );
  }
}
