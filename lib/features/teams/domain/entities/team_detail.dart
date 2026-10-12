import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/entities/team_ref.dart';
import 'team.dart';

/// Partido de la ficha con su contexto de competición.
final class TeamMatch extends Equatable {
  const TeamMatch({
    required this.match,
    required this.competitionName,
    required this.stageLabel,
    this.phaseLabel,
  });

  final Match match;

  /// «Primera División» (con el año si no es la temporada actual).
  final String competitionName;

  /// «Apertura» o «Clausura»; `null` en competiciones de una sola fase o
  /// sin fase determinada.
  final String? phaseLabel;

  /// «Fecha 12», «Semifinales»… («Ronda N» sin fase determinada).
  final String stageLabel;

  @override
  List<Object?> get props => [match, competitionName, phaseLabel, stageLabel];
}

/// Avance de la descarga de las rondas del equipo (P2).
final class TeamSyncProgress extends Equatable {
  const TeamSyncProgress({
    this.done = 0,
    this.total = 0,
    this.isRunning = true,
    this.failure,
  });

  /// Rondas al día (vigentes o recién descargadas).
  final int done;

  /// Rondas de la temporada de las competiciones del equipo; `0` mientras
  /// todavía no se sabe cuáles son.
  final int total;
  final bool isRunning;

  /// La descarga se detuvo por este error (se muestran los guardados).
  final Failure? failure;

  @override
  List<Object?> get props => [done, total, isRunning, failure];
}

/// Ficha de un equipo: datos y partidos de todas las competiciones
/// guardadas.
final class TeamDetail extends Equatable {
  const TeamDetail({
    required this.teamId,
    this.team,
    this.info,
    this.infoError,
    this.competitionIds = const [],
    this.upcoming = const [],
    this.played = const [],
    this.progress = const TeamSyncProgress(),
  });

  final int teamId;

  /// Nombre y escudo; `null` si todavía no hay datos del equipo.
  final TeamRef? team;

  /// Datos de `lookupteam` (estadio, ciudad), si están.
  final Team? info;

  /// `lookupteam` falló (sin datos guardados).
  final Failure? infoError;

  /// Competiciones del catálogo que juega en la temporada.
  final List<int> competitionIds;

  /// En juego y por jugarse, del más próximo al más lejano.
  final List<TeamMatch> upcoming;

  /// Terminados (o con fecha pasada), del más reciente al más viejo.
  final List<TeamMatch> played;
  final TeamSyncProgress progress;

  @override
  List<Object?> get props => [
    teamId,
    team,
    info,
    infoError,
    competitionIds,
    upcoming,
    played,
    progress,
  ];
}
