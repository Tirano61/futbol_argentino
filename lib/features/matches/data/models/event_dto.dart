/// Evento de TheSportsDB tal como llega (`events[]` de `eventsround`,
/// `lookupevent`, `eventsnextleague`…). Solo los campos que usa la app.
///
/// El parsing es tolerante: los valores vacíos o con espacios se toman como
/// `null` y los números pueden venir como texto o como número.
class EventDto {
  const EventDto({
    required this.idEvent,
    required this.idLeague,
    required this.strLeague,
    required this.strSeason,
    required this.intRound,
    required this.idHomeTeam,
    required this.strHomeTeam,
    required this.strHomeTeamBadge,
    required this.idAwayTeam,
    required this.strAwayTeam,
    required this.strAwayTeamBadge,
    required this.intHomeScore,
    required this.intAwayScore,
    this.intHomeScoreExtra,
    this.intAwayScoreExtra,
    required this.strTimestamp,
    required this.dateEvent,
    required this.strTime,
    required this.strTimeLocal,
    required this.dateEventLocal,
    required this.strStatus,
    required this.strPostponed,
    required this.strVenue,
    required this.strThumb,
    required this.strVideo,
  });

  factory EventDto.fromJson(Map<String, dynamic> json) => EventDto(
    idEvent: _int(json['idEvent']),
    idLeague: _int(json['idLeague']),
    strLeague: _text(json['strLeague']),
    strSeason: _text(json['strSeason']),
    intRound: _int(json['intRound']),
    idHomeTeam: _int(json['idHomeTeam']),
    strHomeTeam: _text(json['strHomeTeam']),
    strHomeTeamBadge: _text(json['strHomeTeamBadge']),
    idAwayTeam: _int(json['idAwayTeam']),
    strAwayTeam: _text(json['strAwayTeam']),
    strAwayTeamBadge: _text(json['strAwayTeamBadge']),
    intHomeScore: _int(json['intHomeScore']),
    intAwayScore: _int(json['intAwayScore']),
    intHomeScoreExtra: _int(json['intHomeScoreExtra']),
    intAwayScoreExtra: _int(json['intAwayScoreExtra']),
    strTimestamp: _text(json['strTimestamp']),
    dateEvent: _text(json['dateEvent']),
    strTime: _text(json['strTime']),
    strTimeLocal: _text(json['strTimeLocal']),
    dateEventLocal: _text(json['dateEventLocal']),
    strStatus: _text(json['strStatus']),
    strPostponed: _text(json['strPostponed']),
    strVenue: _text(json['strVenue']),
    strThumb: _text(json['strThumb']),
    strVideo: _text(json['strVideo']),
  );

  final int? idEvent;
  final int? idLeague;
  final String? strLeague;
  final String? strSeason;
  final int? intRound;
  final int? idHomeTeam;
  final String? strHomeTeam;
  final String? strHomeTeamBadge;
  final int? idAwayTeam;
  final String? strAwayTeam;
  final String? strAwayTeamBadge;
  final int? intHomeScore;
  final int? intAwayScore;

  /// Goles de la tanda de penales (`PEN`); vacíos en el resto de los
  /// partidos grabados y en algunos `PEN` (32avos de la Copa 2026).
  final int? intHomeScoreExtra;
  final int? intAwayScoreExtra;
  final String? strTimestamp;
  final String? dateEvent;
  final String? strTime;
  final String? strTimeLocal;
  final String? dateEventLocal;
  final String? strStatus;
  final String? strPostponed;
  final String? strVenue;
  final String? strThumb;
  final String? strVideo;

  static String? _text(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _int(Object? value) => switch (value) {
    final int n => n,
    final num n when n == n.truncate() => n.toInt(),
    final String s => int.tryParse(s.trim()),
    _ => null,
  };
}
