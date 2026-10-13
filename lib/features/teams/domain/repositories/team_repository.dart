import '../../../../core/result/data_result.dart';
import '../../../../core/sync/sync_scheduler.dart';
import '../entities/team.dart';
import '../entities/team_pointers.dart';
import '../entities/team_summary.dart';

abstract interface class TeamRepository {
  /// Equipos que aparecen en los partidos guardados (sin red), con las
  /// competiciones de su temporada más reciente.
  Future<List<TeamSummary>> storedTeams();

  /// Búsqueda en línea (`searchteams`), solo equipos de fútbol de
  /// Argentina. Lanza `Failure` si la consulta falla.
  Future<List<Team>> searchOnline(String query);

  /// Datos del equipo (`lookupteam`), guardados 7 días.
  ///
  /// Lanza `Failure` si no hay datos guardados y la consulta falla.
  Future<DataResult<Team>> getTeam(int teamId, {bool forceRefresh = false});

  /// Próximo y último partido del equipo, de cualquier competición
  /// (`eventsnext` + `eventslast`: 2 peticiones), guardados 30 minutos.
  ///
  /// Lanza `Failure` si no hay datos guardados y la consulta falla.
  Future<DataResult<TeamPointers>> getTeamPointers(
    int teamId, {
    bool forceRefresh = false,
    SyncPriority priority = SyncPriority.context,
  });
}
