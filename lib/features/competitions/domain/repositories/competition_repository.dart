import '../../../../core/result/data_result.dart';
import '../../../matches/domain/entities/match.dart';
import '../entities/competition.dart';

/// Próximo y último partido de una competición (`eventsnextleague` y
/// `eventspastleague`, 1 resultado cada uno con la clave gratuita). Sirven
/// para descubrir la ronda actual.
final class SchedulePointers {
  const SchedulePointers({this.next, this.last});

  final Match? next;
  final Match? last;
}

abstract interface class CompetitionRepository {
  /// Datos de la competición (`lookupleague`): escudo y temporada actual.
  ///
  /// Lanza `Failure` si no hay datos guardados y la consulta falla.
  Future<DataResult<Competition>> getCompetition(int competitionId);

  /// Lanza `Failure` si no hay datos guardados y la consulta falla.
  Future<DataResult<SchedulePointers>> getSchedulePointers(
    int competitionId, {
    bool forceRefresh = false,
  });
}
