import 'package:equatable/equatable.dart';

import 'season.dart';

enum CompetitionFormat { league, cup }

/// Competición con los datos que informa la API (`lookupleague`).
final class Competition extends Equatable {
  const Competition({
    required this.id,
    required this.name,
    required this.shortName,
    required this.format,
    this.badgeUrl,
    this.currentSeason,
  });

  /// `idLeague` de TheSportsDB.
  final int id;
  final String name;
  final String shortName;
  final CompetitionFormat format;
  final String? badgeUrl;
  final Season? currentSeason;

  @override
  List<Object?> get props => [
    id,
    name,
    shortName,
    format,
    badgeUrl,
    currentSeason,
  ];
}
