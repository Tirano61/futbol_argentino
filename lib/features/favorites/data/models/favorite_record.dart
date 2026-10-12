import '../../domain/entities/favorite_team.dart';

/// Forma en que se guarda un [FavoriteTeam] en la base local (store
/// `favorites`).
abstract final class FavoriteRecord {
  static const schemaVersion = 1;

  static Map<String, Object?> toMap(FavoriteTeam f) => {
    'v': schemaVersion,
    'teamId': f.teamId,
    'name': f.name,
    'badgeUrl': f.badgeUrl,
    'addedAt': f.addedAt.toIso8601String(),
  };

  static FavoriteTeam fromMap(Map<String, Object?> map) => FavoriteTeam(
    teamId: map['teamId']! as int,
    name: map['name']! as String,
    badgeUrl: map['badgeUrl'] as String?,
    addedAt: DateTime.parse(map['addedAt']! as String).toUtc(),
  );
}
