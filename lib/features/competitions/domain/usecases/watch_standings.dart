import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/sync/cancel_token.dart';
import '../../../../core/sync/sync_progress.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../catalog/competition_catalog.dart';
import '../entities/season.dart';
import '../entities/season_completion.dart';
import '../standings/regular_season_matches.dart';
import '../standings/standings_table.dart';
import '../standings/table_builders.dart';
import '../standings/zone_validator.dart';
import 'complete_rounds.dart';
import 'refresh_recent_rounds.dart';

/// Tablas de una competición y temporada a medida que se completan.
final class StandingsView extends Equatable {
  const StandingsView({
    required this.competitionId,
    required this.season,
    required this.tables,
    required this.progress,
    this.zoneIssues = const [],
    this.zoneNoun = 'zona',
    this.hasMatches = true,
  }) : isAvailable = true;

  /// La competición no tiene tablas verificadas en esa temporada.
  const StandingsView.unavailable({
    required this.competitionId,
    required this.season,
  }) : tables = const [],
       progress = const SyncProgress(isRunning: false),
       zoneIssues = const [],
       zoneNoun = 'zona',
       hasMatches = false,
       isAvailable = false;

  final int competitionId;
  final Season season;

  /// Primera: la anual primero y después las de zona; Nacional: las de
  /// zona; copas internacionales: las de grupo. Las de zona, solo si las
  /// zonas se verificaron (si no, puede quedar vacía aunque haya
  /// partidos); en las copas, cada grupo por separado.
  final List<StandingsTable> tables;
  final SyncProgress progress;

  /// Por qué no hay tablas por zona («zonas no verificadas»).
  final List<String> zoneIssues;

  /// Cómo se llaman las zonas de la competición: «zona» o «grupo».
  final String zoneNoun;

  /// Hay partidos guardados de la fase regular.
  final bool hasMatches;

  /// La competición tiene tablas verificadas en esa temporada.
  final bool isAvailable;

  StandingsTable? table(String key) =>
      tables.where((t) => t.key == key).firstOrNull;

  @override
  List<Object?> get props => [
    competitionId,
    season,
    tables,
    progress,
    zoneIssues,
    zoneNoun,
    hasMatches,
    isAvailable,
  ];
}

/// Tablas de una temporada (T13.4): lo guardado enseguida y, con
/// [CompleteRounds] (P2), las fechas regulares que falten; recalcula con
/// cada ronda que llega.
///
/// Con `forceRefresh` (refresco manual), primero se fuerzan con P0 las
/// rondas con partidos sin terminar de ayer y de hoy, y después se piden
/// también las vencidas cerradas o históricas (nunca las vigentes).
class WatchStandings {
  const WatchStandings(
    this._matches, {
    List<CompetitionDefinition> catalog = CompetitionCatalog.all,
  }) : _catalog = catalog;

  final MatchRepository _matches;
  final List<CompetitionDefinition> _catalog;

  Stream<StandingsView> call(
    int competitionId,
    Season season, {
    required DateTime now,
    required CancelToken cancelToken,
    bool forceRefresh = false,
  }) async* {
    final definition = _catalog.where((d) => d.id == competitionId).firstOrNull;
    final format = definition?.standingsFor(season);
    if (definition == null || format is! ZonedStandingsFormat) {
      yield StandingsView.unavailable(
        competitionId: competitionId,
        season: season,
      );
      return;
    }

    var forced = 0;
    Failure? forcedFailure;
    if (forceRefresh) {
      try {
        (
          fetched: forced,
          failure: forcedFailure,
        ) = await RefreshRecentRounds(_matches, catalog: _catalog)(
          competitionId,
          season,
          now: now,
          cancelToken: cancelToken,
          rounds: format.regularRounds,
        );
      } on SyncCancelled {
        return;
      }
    }

    await for (final completion in CompleteRounds(_matches, catalog: _catalog)(
      competitionId,
      season,
      now: now,
      cancelToken: cancelToken,
      rounds: format.regularRounds,
      forceRefresh: forceRefresh,
      // Un 429 en el paso forzado ya agotó lo que el scheduler intenta: el
      // resto de la descarga fallaría igual, después de otra pausa (R3.1).
      // Lo mismo si falló la recuperación de un posible 429 oculto (R4).
      fetch: !(forcedFailure?.limitsQueries ?? false),
    )) {
      final p = completion.progress;
      yield _build(
        definition,
        format,
        completion,
        SyncProgress(
          done: p.done,
          total: p.total,
          isRunning: p.isRunning,
          failure: p.failure ?? (p.isRunning ? null : forcedFailure),
          fetched: p.fetched + forced,
        ),
      );
    }
  }

  static StandingsView _build(
    CompetitionDefinition definition,
    ZonedStandingsFormat format,
    SeasonCompletion completion,
    SyncProgress progress,
  ) {
    final season = completion.season;
    final matches = RegularSeasonMatches.classify(
      definition: definition,
      season: season,
      matches: completion.matches,
      rounds: format.regularRounds,
      tournaments: format.tournaments,
    );
    final queried = completion.rounds
        .where((r) => r.status != RoundCompletionStatus.missing)
        .length;
    final hasMatches =
        matches.all.isNotEmpty || matches.undetermined.isNotEmpty;
    if (!hasMatches) {
      return StandingsView(
        competitionId: completion.competitionId,
        season: season,
        tables: const [],
        progress: progress,
        zoneNoun: format.zoneNoun,
        hasMatches: false,
      );
    }

    final validation = ZoneValidator.validate(format, matches);
    final zonesOk = validation.isValid;
    return StandingsView(
      competitionId: completion.competitionId,
      season: season,
      tables: switch (format) {
        LeagueZonesWithAnnual() => [
          AnnualTableBuilder.build(
            format: format,
            season: season,
            matches: matches,
            roundsQueried: queried,
          ),
          if (zonesOk)
            for (final MapEntry(key: tournament, value: zones)
                in format.zones.entries)
              for (final zone in zones.keys)
                ZoneTableBuilder.build(
                  format: format,
                  season: season,
                  tournament: tournament,
                  zone: zone,
                  matches: matches,
                  roundsQueried: queried,
                ),
        ],
        LeagueZones() => [
          if (zonesOk)
            for (final zone in format.zones.keys)
              LeagueZoneTableBuilder.build(
                format: format,
                season: season,
                zone: zone,
                matches: matches,
                roundsQueried: queried,
              ),
        ],
        // Cada grupo por separado: uno que no coincide no tapa a los demás.
        GroupStage() => [
          for (final group in format.groups.keys)
            if (!validation.invalidZones.contains(group))
              GroupTableBuilder.build(
                format: format,
                season: season,
                group: group,
                matches: matches,
                roundsQueried: queried,
              ),
        ],
      },
      progress: progress,
      zoneIssues: validation.issues,
      zoneNoun: format.zoneNoun,
    );
  }
}
