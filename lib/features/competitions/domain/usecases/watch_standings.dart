import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/sync/cancel_token.dart';
import '../../../../core/sync/sync_progress.dart';
import '../../../../core/sync/sync_scheduler.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../catalog/competition_catalog.dart';
import '../entities/season.dart';
import '../entities/season_completion.dart';
import '../standings/regular_season_matches.dart';
import '../standings/standings_table.dart';
import '../standings/table_builders.dart';
import '../standings/zone_validator.dart';
import 'complete_rounds.dart';

/// Tablas de una competición y temporada a medida que se completan.
final class StandingsView extends Equatable {
  const StandingsView({
    required this.competitionId,
    required this.season,
    required this.tables,
    required this.progress,
    this.zoneIssues = const [],
    this.hasMatches = true,
  }) : isAvailable = true;

  /// La competición no tiene tablas verificadas en esa temporada.
  const StandingsView.unavailable({
    required this.competitionId,
    required this.season,
  }) : tables = const [],
       progress = const SyncProgress(isRunning: false),
       zoneIssues = const [],
       hasMatches = false,
       isAvailable = false;

  final int competitionId;
  final Season season;

  /// Primera: la anual primero y después las de zona; Nacional: las de
  /// zona. Las de zona, solo si las zonas se verificaron (si no, puede
  /// quedar vacía aunque haya partidos).
  final List<StandingsTable> tables;
  final SyncProgress progress;

  /// Por qué no hay tablas por zona («zonas no verificadas»).
  final List<String> zoneIssues;

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
      final rounds = await _roundsToForce(
        competitionId,
        season,
        format.regularRounds,
        now,
      );
      for (final query in rounds) {
        try {
          final queried = await _matches.syncRound(
            query,
            priority: SyncPriority.visible,
            forceRefresh: true,
            cancelToken: cancelToken,
          );
          if (queried) forced++;
        } on SyncCancelled {
          return;
        } on Failure catch (failure) {
          forcedFailure = failure;
          break;
        }
      }
    }

    await for (final completion in CompleteRounds(_matches, catalog: _catalog)(
      competitionId,
      season,
      now: now,
      cancelToken: cancelToken,
      rounds: format.regularRounds,
      forceRefresh: forceRefresh,
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
      },
      progress: progress,
      zoneIssues: validation.issues,
    );
  }

  /// Rondas con partidos guardados sin terminar de ayer o de hoy (o en
  /// juego).
  Future<List<RoundQuery>> _roundsToForce(
    int competitionId,
    Season season,
    List<int> rounds,
    DateTime now,
  ) async {
    final today = ArgentinaTime.dayOf(now);
    bool recent(Match m) {
      if (m.status.isInPlay) return true;
      final day = m.kickoff.argentinaDay;
      return !m.status.isFinished &&
          day != null &&
          !day.isBefore(today.addDays(-1)) &&
          !day.isAfter(today);
    }

    final stored = await _matches.storedSeason(competitionId, season.apiValue);
    final definition = _catalog.firstWhere((d) => d.id == competitionId);
    return [
      for (final r in {
        for (final m in stored)
          if (rounds.contains(m.apiRound) && recent(m)) m.apiRound,
      })
        RoundQuery(
          competitionId: competitionId,
          season: season.apiValue,
          apiRound: r,
          expectedMinimum: definition.expectedMinimumMatches(r),
        ),
    ];
  }
}
