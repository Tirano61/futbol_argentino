import 'package:equatable/equatable.dart';

/// Temporada con partidos guardados en el dispositivo («Datos guardados»).
final class StoredSeason extends Equatable {
  const StoredSeason({
    required this.competitionId,
    required this.competitionName,
    required this.season,
    required this.matchCount,
    required this.isCurrent,
  });

  final int competitionId;
  final String competitionName;

  /// Temporada en formato de la API (`"2025"`).
  final String season;
  final int matchCount;

  /// La temporada actual (o una posterior): no se puede borrar.
  final bool isCurrent;

  bool get canDelete => !isCurrent;

  /// Identifica la temporada de la competición (`4406:2025`).
  String get key => '$competitionId:$season';

  @override
  List<Object?> get props => [
    competitionId,
    competitionName,
    season,
    matchCount,
    isCurrent,
  ];
}
