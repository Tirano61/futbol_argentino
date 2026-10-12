import 'package:equatable/equatable.dart';

import '../../../matches/domain/entities/team_ref.dart';

/// Equipo marcado como favorito en este dispositivo: el `idTeam` y una
/// copia del nombre y el escudo de cuando se agregó (para mostrarlo sin red).
final class FavoriteTeam extends Equatable {
  const FavoriteTeam({
    required this.teamId,
    required this.name,
    required this.addedAt,
    this.badgeUrl,
  });

  factory FavoriteTeam.fromRef(TeamRef team, {required DateTime addedAt}) =>
      FavoriteTeam(
        teamId: team.id,
        name: team.name,
        badgeUrl: team.badgeUrl,
        addedAt: addedAt,
      );

  final int teamId;
  final String name;
  final String? badgeUrl;

  /// Cuándo se agregó (UTC).
  final DateTime addedAt;

  TeamRef get ref => TeamRef(id: teamId, name: name, badgeUrl: badgeUrl);

  @override
  List<Object?> get props => [teamId, name, badgeUrl, addedAt];
}
