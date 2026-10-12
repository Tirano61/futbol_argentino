import 'package:equatable/equatable.dart';

import '../../../../core/result/data_result.dart';
import '../../../../core/sync/cancel_token.dart';
import '../../../../core/sync/sync_scheduler.dart';
import '../entities/match.dart';

/// Una ronda de la API: la unidad de carga incremental (§5.1).
final class RoundQuery extends Equatable {
  const RoundQuery({
    required this.competitionId,
    required this.season,
    required this.apiRound,
    this.expectedMinimum,
  });

  final int competitionId;

  /// Temporada en formato de la API (`"2026"`).
  final String season;
  final int apiRound;

  /// Partidos mínimos esperados (del catálogo), para detectar respuestas
  /// incompletas. No forma parte de la identidad de la consulta.
  final int? expectedMinimum;

  @override
  List<Object?> get props => [competitionId, season, apiRound];
}

abstract interface class MatchRepository {
  /// Partidos visibles de una ronda (todas sus fases).
  ///
  /// Emite primero lo guardado, si existe, y después la versión actualizada
  /// cuando la caché venció o [forceRefresh] es `true`. Si la actualización
  /// falla y hay datos guardados, emite esos datos con `refreshError`. Si no
  /// hay nada guardado y falla, emite un error `Failure`.
  ///
  /// [priority]: P0 para lo que se está mirando; P1 para contexto (Inicio).
  Stream<DataResult<List<Match>>> watchRound(
    RoundQuery query, {
    bool forceRefresh = false,
    SyncPriority priority = SyncPriority.visible,
  });

  /// Descarga una ronda en segundo plano, con prioridad baja, si lo
  /// guardado venció (p. ej. la etapa vecina). No lanza errores.
  Future<void> prefetchRound(RoundQuery query);

  /// Actualiza una ronda guardada si venció (o si [forceRefresh] y pasó el
  /// mínimo entre refrescos), sin devolver sus partidos.
  ///
  /// Devuelve `true` si consultó la red y `false` si la ronda estaba
  /// vigente (o, con [forceRefresh], se actualizó hace menos de 30 s).
  ///
  /// Lanza `Failure` si la consulta falla y `SyncCancelled` si
  /// [cancelToken] se cancela antes de empezar.
  Future<bool> syncRound(
    RoundQuery query, {
    SyncPriority priority = SyncPriority.context,
    bool forceRefresh = false,
    CancelToken? cancelToken,
  });

  /// Partidos visibles guardados de una ronda (sin red).
  Future<List<Match>> storedRound(RoundQuery query);

  /// Partidos guardados de un equipo, de todas las competiciones, salvo los
  /// que la API dio de baja (sin red).
  Future<List<Match>> storedTeamMatches(int teamId);

  /// Partidos guardados de esos equipos, salvo los dados de baja (sin red).
  /// Emite enseguida y de nuevo cada vez que se guardan partidos.
  Stream<List<Match>> watchStoredTeamsMatches(Set<int> teamIds);

  /// Un partido por `idEvent` (caché y, si venció, `lookupevent`).
  ///
  /// Lanza `Failure` si no hay datos guardados y la consulta falla.
  Future<DataResult<Match>> getMatch(int matchId, {bool forceRefresh = false});
}
