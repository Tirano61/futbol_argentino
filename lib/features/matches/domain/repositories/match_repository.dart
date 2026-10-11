import 'package:equatable/equatable.dart';

import '../../../../core/result/data_result.dart';
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
  Stream<DataResult<List<Match>>> watchRound(
    RoundQuery query, {
    bool forceRefresh = false,
  });

  /// Un partido por `idEvent` (caché y, si venció, `lookupevent`).
  ///
  /// Lanza `Failure` si no hay datos guardados y la consulta falla.
  Future<DataResult<Match>> getMatch(int matchId, {bool forceRefresh = false});
}
