import 'package:equatable/equatable.dart';

/// Equipo tal como aparece en un partido. `id` es el `idTeam` de TheSportsDB.
final class TeamRef extends Equatable {
  const TeamRef({required this.id, required this.name, this.badgeUrl});

  final int id;
  final String name;
  final String? badgeUrl;

  @override
  List<Object?> get props => [id, name, badgeUrl];
}
