import 'package:equatable/equatable.dart';

import '../../../matches/domain/entities/team_ref.dart';

/// Datos de un equipo (`lookupteam` / `searchteams`). `id` es el `idTeam`.
final class Team extends Equatable {
  const Team({
    required this.id,
    required this.name,
    this.alternateNames = const [],
    this.badgeUrl,
    this.stadium,
    this.location,
    this.leagueIds = const [],
  });

  final int id;
  final String name;
  final List<String> alternateNames;
  final String? badgeUrl;
  final String? stadium;
  final String? location;

  /// Ligas que informa la API (`idLeague`…`idLeague7`); pueden incluir
  /// competiciones fuera del catálogo o estar desactualizadas.
  final List<int> leagueIds;

  TeamRef get ref => TeamRef(id: id, name: name, badgeUrl: badgeUrl);

  @override
  List<Object?> get props => [
    id,
    name,
    alternateNames,
    badgeUrl,
    stadium,
    location,
    leagueIds,
  ];
}
