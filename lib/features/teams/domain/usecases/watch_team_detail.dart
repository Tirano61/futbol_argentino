import '../../../../core/error/failure.dart';
import '../../../../core/sync/cancel_token.dart';
import '../../../../core/sync/sync_scheduler.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../../core/time/calendar_day.dart';
import '../../../competitions/domain/catalog/competition_catalog.dart';
import '../../../competitions/domain/entities/phase_assignment.dart';
import '../../../competitions/domain/entities/season.dart';
import '../../../competitions/domain/services/phase_resolver.dart';
import '../../../competitions/domain/services/round_navigator.dart';
import '../../../competitions/domain/services/stage_labeler.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../../../matches/domain/services/match_grouping.dart';
import '../entities/team.dart';
import '../entities/team_detail.dart';
import '../repositories/team_repository.dart';
import 'ensure_team_index.dart';

/// Ficha de un equipo: emite lo guardado enseguida y se va completando.
///
/// 1. Partidos guardados del equipo, de todas las competiciones.
/// 2. Datos del equipo (`lookupteam`, P0) y primera etapa de cada
///    competición ([EnsureTeamIndex], P1): así se sabe qué competiciones
///    juega en la temporada.
/// 3. Todas las rondas de la temporada de esas competiciones, de a una
///    (P2, con cupo propio): primero las más recientes y alternando
///    competiciones. Las vigentes no generan peticiones.
///
/// Cancelar [cancelToken] (al salir de la ficha) descarta las rondas que
/// faltan. Un error detiene la descarga: las siguientes fallarían igual.
class WatchTeamDetail {
  const WatchTeamDetail({
    required TeamRepository teams,
    required MatchRepository matches,
    List<CompetitionDefinition> catalog = CompetitionCatalog.all,
  }) : _teams = teams,
       _matches = matches,
       _catalog = catalog;

  final TeamRepository _teams;
  final MatchRepository _matches;
  final List<CompetitionDefinition> _catalog;

  /// En un refresco manual se fuerzan (P0) las rondas con partidos del
  /// equipo sin terminar entre ayer y dentro de 7 días; el resto respeta
  /// la vigencia.
  static const refreshDaysBack = 1;
  static const refreshDaysAhead = 7;

  Stream<TeamDetail> call(
    int teamId, {
    required DateTime now,
    required CancelToken cancelToken,
    bool forceRefresh = false,
  }) async* {
    final today = ArgentinaTime.dayOf(now);
    final phases = _RoundPhases(_matches, _catalog);
    Team? info;
    Failure? infoError;

    Future<TeamDetail> build(TeamSyncProgress progress) async {
      final stored = await _matches.storedTeamMatches(teamId);
      final season = _seasonOf(stored, today);
      final items = [
        for (final m in stored) await phases.describe(m, season, teamId),
      ];
      final latest = MatchGrouping.dedupe(stored)
        ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
      return TeamDetail(
        teamId: teamId,
        team:
            info?.ref ??
            switch (latest.firstOrNull) {
              final m? => m.home.id == teamId ? m.home : m.away,
              null => null,
            },
        info: info,
        infoError: infoError,
        competitionIds: [
          for (final d in _catalog)
            if (stored.any(
              (m) => m.competitionId == d.id && m.season == season.apiValue,
            ))
              d.id,
        ],
        upcoming: [
          for (final i in items)
            if (!_isPlayed(i.match, today)) i,
        ]..sort((a, b) => MatchGrouping.compare(a.match, b.match)),
        played: [
          for (final i in items)
            if (_isPlayed(i.match, today)) i,
        ]..sort((a, b) => MatchGrouping.compare(b.match, a.match)),
        progress: progress,
      );
    }

    yield await build(const TeamSyncProgress());

    final infoRequest = _loadInfo(teamId, forceRefresh);
    Failure? failure = await EnsureTeamIndex(_matches, catalog: _catalog)(
      now: now,
    );
    (info, infoError) = await infoRequest;
    if (cancelToken.isCancelled) return;

    final stored = await _matches.storedTeamMatches(teamId);
    final plan = failure != null
        ? const <({RoundQuery query, bool force})>[]
        : _plan(stored, _seasonOf(stored, today), today, forceRefresh);
    var done = 0;
    yield await build(TeamSyncProgress(total: plan.length));

    for (final step in plan) {
      try {
        await _matches.syncRound(
          step.query,
          priority: step.force ? SyncPriority.visible : SyncPriority.team,
          forceRefresh: step.force,
          cancelToken: cancelToken,
        );
      } on SyncCancelled {
        return;
      } on Failure catch (error) {
        failure = error;
        break;
      }
      if (cancelToken.isCancelled) return;
      done++;
      phases.invalidate(step.query);
      yield await build(TeamSyncProgress(done: done, total: plan.length));
    }

    yield await build(
      TeamSyncProgress(
        done: done,
        total: plan.length,
        isRunning: false,
        failure: failure,
      ),
    );
  }

  CompetitionDefinition? _definition(int id) =>
      _catalog.where((d) => d.id == id).firstOrNull;

  Future<(Team?, Failure?)> _loadInfo(int teamId, bool forceRefresh) async {
    try {
      final result = await _teams.getTeam(teamId, forceRefresh: forceRefresh);
      return (result.data, null);
    } on Failure catch (failure) {
      return (null, failure);
    }
  }

  /// La temporada del año argentino si el equipo tiene partidos guardados
  /// en ella; si no (p. ej. en enero), la más reciente que tenga.
  Season _seasonOf(List<Match> stored, CalendarDay today) {
    final current = Season(today.year);
    Season? latest;
    for (final m in stored) {
      if (_definition(m.competitionId) == null) continue;
      final season = Season.tryParse(m.season);
      if (season == current) return current;
      if (season != null && (latest == null || season.compareTo(latest) > 0)) {
        latest = season;
      }
    }
    return latest ?? current;
  }

  /// Terminado, o con fecha pasada y sin estar en juego.
  static bool _isPlayed(Match m, CalendarDay today) {
    if (m.status.isFinished) return true;
    if (m.status.isInPlay) return false;
    final day = m.kickoff.argentinaDay;
    return day != null && day.isBefore(today);
  }

  /// Rondas a sincronizar: primero las forzadas por un refresco manual;
  /// después las de la temporada, de la última a la primera, alternando
  /// competiciones.
  List<({RoundQuery query, bool force})> _plan(
    List<Match> stored,
    Season season,
    CalendarDay today,
    bool forceRefresh,
  ) {
    final byCompetition = <List<RoundQuery>>[];
    for (final d in _catalog) {
      final mine = [
        for (final m in stored)
          if (m.competitionId == d.id && m.season == season.apiValue) m,
      ];
      if (mine.isEmpty) continue;
      // Sin cantidad de fechas en el catálogo: hasta la última guardada.
      final lastKnown = mine.map((m) => m.apiRound).reduce(_max);
      final rounds = <int>{
        for (final phase in d.phases)
          for (final s in RoundNavigator.stagesFor(
            d,
            season,
            phase,
            knownMaxRound: lastKnown,
          ))
            s.apiRound,
      };
      byCompetition.add([
        for (final r in rounds.toList().reversed) _query(d, season.apiValue, r),
      ]);
    }

    final forced = <RoundQuery>{
      if (forceRefresh)
        for (final m in stored)
          if (!m.status.isFinished && _inRefreshWindow(m, today))
            if (_definition(m.competitionId) case final d?)
              _query(d, m.season, m.apiRound),
    };
    final ordered = <RoundQuery>{...forced};
    final longest = byCompetition.map((l) => l.length).fold(0, _max);
    for (var i = 0; i < longest; i++) {
      for (final rounds in byCompetition) {
        if (i < rounds.length) ordered.add(rounds[i]);
      }
    }
    return [for (final q in ordered) (query: q, force: forced.contains(q))];
  }

  static bool _inRefreshWindow(Match m, CalendarDay today) {
    final day = m.kickoff.argentinaDay;
    return day != null &&
        !day.isBefore(today.addDays(-refreshDaysBack)) &&
        !day.isAfter(today.addDays(refreshDaysAhead));
  }

  static RoundQuery _query(
    CompetitionDefinition d,
    String season,
    int apiRound,
  ) => RoundQuery(
    competitionId: d.id,
    season: season,
    apiRound: apiRound,
    expectedMinimum: d.expectedMinimumMatches(apiRound),
  );

  static int _max(int a, int b) => a > b ? a : b;
}

/// Fase de los partidos del equipo, calculada con la ronda guardada
/// completa (consistencia e inferencia) y recordada por ronda.
final class _RoundPhases {
  _RoundPhases(this._matches, this._catalog);

  final MatchRepository _matches;
  final List<CompetitionDefinition> _catalog;
  final _byRound = <RoundQuery, Map<int, PhaseAssignment>>{};

  void invalidate(RoundQuery query) => _byRound.remove(query);

  Future<TeamMatch> describe(Match m, Season current, int teamId) async {
    final definition = _catalog
        .where((d) => d.id == m.competitionId)
        .firstOrNull;
    final season = Season.tryParse(m.season);
    if (definition == null || season == null) {
      return TeamMatch(
        match: m,
        competitionName: m.competitionName,
        stageLabel: 'Ronda ${m.apiRound}',
      );
    }

    final query = RoundQuery(
      competitionId: m.competitionId,
      season: m.season,
      apiRound: m.apiRound,
    );
    var assigned = _byRound[query];
    if (assigned == null || !assigned.containsKey(m.id)) {
      final round = await _matches.storedRound(query);
      assigned = _byRound[query] = PhaseResolver(definition).classifyRound(
        season: season,
        apiRound: m.apiRound,
        matches: [
          for (final r in round)
            if (r.id != m.id) r,
          m,
        ],
      );
    }
    final labels = StageLabeler.describe(
      definition,
      m.apiRound,
      assigned[m.id]!,
    );
    return TeamMatch(
      match: m,
      competitionName: season == current
          ? definition.name
          : '${definition.name} ${m.season}',
      phaseLabel: labels.phase,
      stageLabel: labels.stage,
    );
  }
}
