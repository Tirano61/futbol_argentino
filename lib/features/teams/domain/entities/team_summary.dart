import 'package:equatable/equatable.dart';

import '../../../matches/domain/entities/team_ref.dart';

/// Equipo en una lista de búsqueda.
final class TeamSummary extends Equatable {
  const TeamSummary({required this.team, this.competitionIds = const []});

  final TeamRef team;

  /// Competiciones del catálogo en las que juega: en el índice local, las
  /// de su temporada más reciente guardada.
  final List<int> competitionIds;

  @override
  List<Object?> get props => [team, competitionIds];
}
