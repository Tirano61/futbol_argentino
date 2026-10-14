import '../../domain/entities/match.dart';
import '../../domain/entities/match_status.dart';
import '../../domain/entities/score.dart';
import '../../domain/entities/team_ref.dart';
import '../../domain/services/kickoff_resolver.dart';
import '../../domain/services/match_status_mapper.dart';
import '../models/event_dto.dart';

abstract final class EventMapper {
  /// Convierte un evento en [Match]. Devuelve `null` si le faltan los
  /// identificadores imprescindibles (`idEvent`, `idLeague` o los `idTeam`):
  /// sin ellos no se puede deduplicar ni asociar al equipo.
  ///
  /// [season] y [apiRound] se usan solo si el evento no los trae.
  static Match? toEntity(
    EventDto dto, {
    required DateTime seenAt,
    String? season,
    int? apiRound,
  }) {
    final id = dto.idEvent;
    final competitionId = dto.idLeague;
    final homeId = dto.idHomeTeam;
    final awayId = dto.idAwayTeam;
    final eventSeason = dto.strSeason ?? season;
    final round = dto.intRound ?? apiRound;
    if (id == null ||
        competitionId == null ||
        homeId == null ||
        awayId == null ||
        eventSeason == null ||
        round == null) {
      return null;
    }

    final home = dto.intHomeScore;
    final away = dto.intAwayScore;
    final status = MatchStatusMapper.fromApi(
      dto.strStatus,
      postponed: dto.strPostponed,
    );
    final homePenalties = dto.intHomeScoreExtra;
    final awayPenalties = dto.intAwayScoreExtra;
    return Match(
      id: id,
      competitionId: competitionId,
      competitionName: dto.strLeague ?? '',
      season: eventSeason,
      apiRound: round,
      home: TeamRef(
        id: homeId,
        name: dto.strHomeTeam ?? 'Equipo sin nombre',
        badgeUrl: dto.strHomeTeamBadge,
      ),
      away: TeamRef(
        id: awayId,
        name: dto.strAwayTeam ?? 'Equipo sin nombre',
        badgeUrl: dto.strAwayTeamBadge,
      ),
      kickoff: KickoffResolver.resolve(
        timestamp: dto.strTimestamp,
        date: dto.dateEvent,
        time: dto.strTime,
        localTime: dto.strTimeLocal,
        localDate: dto.dateEventLocal,
      ),
      status: status,
      score: home != null && away != null
          ? Score(home: home, away: away)
          : null,
      // Solo en partidos definidos por penales: en otros torneos de la API
      // `…ScoreExtra` puede ser otra cosa.
      penalties:
          status.decidedBy == MatchDecision.penalties &&
              homePenalties != null &&
              awayPenalties != null
          ? Score(home: homePenalties, away: awayPenalties)
          : null,
      venue: dto.strVenue,
      thumbUrl: dto.strThumb,
      videoUrl: dto.strVideo,
      lastSeenAt: seenAt,
    );
  }
}
