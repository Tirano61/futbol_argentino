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

/// Vigencia de una ronda guardada.
enum RoundFreshness {
  /// Nunca se descargó (o se borró).
  missing,

  /// Guardada y dentro de su vigencia: no se vuelve a pedir.
  fresh,

  /// Guardada, pero venció su vigencia.
  stale,
}

/// Estado de una ronda en la base local (sin red).
final class RoundCacheState extends Equatable {
  const RoundCacheState({
    required this.freshness,
    this.fetchedAt,
    this.isClosed = false,
    this.isComplete = false,
  });

  static const missing = RoundCacheState(freshness: RoundFreshness.missing);

  final RoundFreshness freshness;

  /// Cuándo se descargó (UTC); `null` si falta.
  final DateTime? fetchedAt;

  /// Al descargarla, todos sus partidos estaban terminados (o cancelados)
  /// hace más de 48 h: vigencia de 30 días.
  final bool isClosed;

  /// La última respuesta trajo la ronda completa (no parcial ni vacía).
  final bool isComplete;

  @override
  List<Object?> get props => [freshness, fetchedAt, isClosed, isComplete];
}

/// Partidos guardados de una temporada de una competición.
final class StoredSeasonSummary extends Equatable {
  const StoredSeasonSummary({
    required this.competitionId,
    required this.competitionName,
    required this.season,
    required this.matchCount,
    this.orphanedCount = 0,
    this.removedCount = 0,
  });

  final int competitionId;

  /// Nombre guardado con los partidos (de la API).
  final String competitionName;

  /// Temporada en formato de la API (`"2025"`).
  final String season;

  /// Todos los partidos guardados (los que se borrarían).
  final int matchCount;

  /// Partidos que su ronda dejó de listar, sin verificar todavía.
  final int orphanedCount;

  /// Partidos que la API confirmó que ya no existen.
  final int removedCount;

  @override
  List<Object?> get props => [
    competitionId,
    competitionName,
    season,
    matchCount,
    orphanedCount,
    removedCount,
  ];
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

  /// Vigencia de una ronda guardada (sin red).
  Future<RoundCacheState> roundCacheState(RoundQuery query);

  /// Partidos visibles guardados de una temporada de una competición, de
  /// todas sus rondas (sin red).
  Future<List<Match>> storedSeason(int competitionId, String season);

  /// Temporadas con partidos guardados, por competición (sin red).
  Future<List<StoredSeasonSummary>> storedSeasons();

  /// Borra los partidos guardados de una temporada de una competición y
  /// sus consultas registradas (`round:*`), para que se vuelvan a pedir si
  /// hacen falta. No toca favoritos, equipos ni otras temporadas.
  ///
  /// Devuelve cuántos partidos borró.
  Future<int> deleteSeason(int competitionId, String season);

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
