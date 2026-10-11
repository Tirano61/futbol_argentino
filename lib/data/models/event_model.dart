import '../../domain/entities/football_match.dart';

/// Evento de TheSportsDB (solo los campos que usa esta prueba).
class EventModel {
  const EventModel({
    required this.strHomeTeam,
    required this.strAwayTeam,
    required this.strTimestamp,
    required this.intHomeScore,
    required this.intAwayScore,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) => EventModel(
    strHomeTeam: _asString(json['strHomeTeam']),
    strAwayTeam: _asString(json['strAwayTeam']),
    strTimestamp: _asString(json['strTimestamp']),
    intHomeScore: _asString(json['intHomeScore']),
    intAwayScore: _asString(json['intAwayScore']),
  );

  final String? strHomeTeam;
  final String? strAwayTeam;
  final String? strTimestamp;
  final String? intHomeScore;
  final String? intAwayScore;

  FootballMatch toEntity() => FootballMatch(
    homeTeam: strHomeTeam ?? 'Equipo no informado',
    awayTeam: strAwayTeam ?? 'Equipo no informado',
    kickoffUtc: parseUtcTimestamp(strTimestamp),
    homeScore: intHomeScore,
    awayScore: intAwayScore,
  );

  static String? _asString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

final _offsetSuffix = RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false);

/// Interpreta `strTimestamp` como UTC. TheSportsDB lo envía sin zona
/// (p. ej. `2026-10-10T18:30:00`), por lo que se le agrega `Z`; si ya trae
/// zona, se respeta. Devuelve `null` si no puede interpretarse.
DateTime? parseUtcTimestamp(String? value) {
  if (value == null || value.isEmpty) return null;
  final normalized = _offsetSuffix.hasMatch(value) ? value : '${value}Z';
  return DateTime.tryParse(normalized)?.toUtc();
}
