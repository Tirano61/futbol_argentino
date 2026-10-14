import 'package:equatable/equatable.dart';

import 'kickoff.dart';
import 'match_status.dart';
import 'score.dart';
import 'team_ref.dart';

/// Relación del partido con la ronda en la que se guardó (ver
/// `RoundMergePolicy`).
enum MatchMembership {
  /// Aparece en la última respuesta de su ronda.
  active,

  /// La API ya no lo lista en su ronda pero `lookupevent` lo confirma:
  /// visible con aviso.
  unconfirmed,

  /// Faltó en una respuesta completa de su ronda: oculto del fixture,
  /// pendiente de verificación.
  orphaned,

  /// La API ya no lo tiene: oculto.
  removed,
}

/// Partido. `id` es el `idEvent` de TheSportsDB (clave de deduplicación).
///
/// La fase (Apertura, Clausura…) no se guarda acá: depende del catálogo de
/// competiciones y la calcula `PhaseResolver`.
final class Match extends Equatable {
  const Match({
    required this.id,
    required this.competitionId,
    required this.competitionName,
    required this.season,
    required this.apiRound,
    required this.home,
    required this.away,
    required this.kickoff,
    required this.status,
    required this.lastSeenAt,
    this.score,
    this.penalties,
    this.venue,
    this.thumbUrl,
    this.videoUrl,
    this.previousKickoffUtc,
    this.previousApiRound,
    this.membership = MatchMembership.active,
  });

  final int id;
  final int competitionId;
  final String competitionName;

  /// Temporada tal como la usa la API (`"2026"`).
  final String season;

  /// `intRound` de la API (en Copa es un código: 64, 125, 150…).
  final int apiRound;

  final TeamRef home;
  final TeamRef away;
  final Kickoff kickoff;
  final MatchStatus status;
  final Score? score;

  /// Tanda de penales, si la API la informa (no siempre: ver `docs/API.md`).
  final Score? penalties;
  final String? venue;
  final String? thumbUrl;
  final String? videoUrl;

  /// Horario confirmado anterior, si el partido se reprogramó.
  final DateTime? previousKickoffUtc;

  /// Ronda anterior, si la API movió el partido de ronda.
  final int? previousApiRound;

  final MatchMembership membership;

  /// Última vez que el partido apareció en una respuesta de la API (UTC).
  final DateTime lastSeenAt;

  bool get wasRescheduled => previousKickoffUtc != null;

  bool get isVisible =>
      membership == MatchMembership.active ||
      membership == MatchMembership.unconfirmed;

  bool involvesTeam(int teamId) => home.id == teamId || away.id == teamId;

  /// Sigue «no comenzado» más de 3 h después de un inicio confirmado: la
  /// UI muestra «Resultado pendiente de actualización» (no se inventa nada).
  bool isResultOverdue(DateTime nowUtc) {
    final start = kickoff.confirmedUtc;
    return status.isScheduled &&
        start != null &&
        nowUtc.isAfter(start.add(const Duration(hours: 3)));
  }

  Match copyWith({
    int? apiRound,
    MatchMembership? membership,
    DateTime? lastSeenAt,
  }) => Match(
    id: id,
    competitionId: competitionId,
    competitionName: competitionName,
    season: season,
    apiRound: apiRound ?? this.apiRound,
    home: home,
    away: away,
    kickoff: kickoff,
    status: status,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    score: score,
    penalties: penalties,
    venue: venue,
    thumbUrl: thumbUrl,
    videoUrl: videoUrl,
    previousKickoffUtc: previousKickoffUtc,
    previousApiRound: previousApiRound,
    membership: membership ?? this.membership,
  );

  @override
  List<Object?> get props => [
    id,
    competitionId,
    competitionName,
    season,
    apiRound,
    home,
    away,
    kickoff,
    status,
    score,
    penalties,
    venue,
    thumbUrl,
    videoUrl,
    previousKickoffUtc,
    previousApiRound,
    membership,
    lastSeenAt,
  ];
}
