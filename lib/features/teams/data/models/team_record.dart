import '../../domain/entities/team.dart';

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
