import '../../domain/catalog/competition_catalog.dart';
import '../../domain/entities/competition.dart';
import '../../domain/entities/season.dart';

/// Liga de TheSportsDB (`leagues[]` de `lookupleague`).
class LeagueDto {
  const LeagueDto({
    required this.idLeague,
    required this.strLeague,
    required this.strCurrentSeason,
    required this.strBadge,
  });

  factory LeagueDto.fromJson(Map<String, dynamic> json) => LeagueDto(
    idLeague: int.tryParse('${json['idLeague'] ?? ''}'.trim()),
    strLeague: _text(json['strLeague']),
    strCurrentSeason: _text(json['strCurrentSeason']),
    strBadge: _text(json['strBadge']),
  );

  final int? idLeague;
  final String? strLeague;
  final String? strCurrentSeason;
  final String? strBadge;

  /// Nombres y formato salen del catálogo; la API aporta escudo y temporada.
  Competition toEntity(CompetitionDefinition definition) => Competition(
    id: definition.id,
    name: definition.name,
    shortName: definition.shortName,
    format: definition.format,
    badgeUrl: strBadge,
    currentSeason: Season.tryParse(strCurrentSeason),
  );

  static String? _text(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
