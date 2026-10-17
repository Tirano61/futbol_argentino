import '../../domain/entities/team.dart';

/// Equipo de TheSportsDB (`teams[]` de `lookupteam` y `searchteams`). Solo
/// los campos que usa la app.
class TeamDto {
  const TeamDto({
    required this.idTeam,
    required this.strTeam,
    required this.strTeamAlternate,
    required this.strBadge,
    required this.strStadium,
    required this.strLocation,
    required this.strCountry,
    required this.strSport,
    required this.leagueIds,
  });

  factory TeamDto.fromJson(Map<String, dynamic> json) => TeamDto(
    idTeam: _int(json['idTeam']),
    strTeam: _text(json['strTeam']),
    strTeamAlternate: _text(json['strTeamAlternate']),
    strBadge: _text(json['strBadge']),
    strStadium: _text(json['strStadium']),
    strLocation: _text(json['strLocation']),
    strCountry: _text(json['strCountry']),
    strSport: _text(json['strSport']),
    leagueIds: [
      for (final key in ['idLeague', for (var i = 2; i <= 7; i++) 'idLeague$i'])
        ?_int(json[key]),
    ],
  );

  final int? idTeam;
  final String? strTeam;

  /// Nombres alternativos separados por coma.
  final String? strTeamAlternate;
  final String? strBadge;
  final String? strStadium;
  final String? strLocation;
  final String? strCountry;
  final String? strSport;
  final List<int> leagueIds;

  bool get isFootball => strSport == 'Soccer';

  bool get isArgentineFootball => strCountry == 'Argentina' && isFootball;

  /// Juega alguna de [leagues] según `idLeague…idLeague7`.
  bool playsAnyOf(Set<int> leagues) => leagueIds.any(leagues.contains);

  /// `null` si falta el id o el nombre.
  Team? toEntity() {
    final id = idTeam;
    final name = strTeam;
    if (id == null || name == null) return null;
    return Team(
      id: id,
      name: name,
      alternateNames: [
        for (final alt in (strTeamAlternate ?? '').split(','))
          if (alt.trim().isNotEmpty) alt.trim(),
      ],
      badgeUrl: strBadge,
      stadium: strStadium,
      location: strLocation,
      leagueIds: leagueIds,
    );
  }

  static int? _int(Object? value) =>
      value == null ? null : int.tryParse('$value'.trim());

  static String? _text(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
