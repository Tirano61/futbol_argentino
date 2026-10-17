import '../../../../core/error/failure.dart';
import '../../../../core/result/data_result.dart';
import '../../../../core/sync/cancel_token.dart';
import '../../../../core/sync/sync_progress.dart';
import '../../../../core/sync/sync_scheduler.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../../core/time/calendar_day.dart';
import '../../../competitions/domain/catalog/competition_catalog.dart';
import '../../../competitions/domain/entities/season.dart';
import '../../../competitions/domain/services/continental_exit_evidence.dart';
import '../../../competitions/domain/services/round_navigator.dart';
import '../../../competitions/domain/services/stored_match_labeler.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../../../matches/domain/services/match_grouping.dart';
import '../entities/team.dart';
import '../entities/team_detail.dart';
import '../entities/team_pointers.dart';
import '../repositories/team_repository.dart';
import 'ensure_team_index.dart';

/// Ficha de un equipo: emite lo guardado enseguida y se va completando.
///
/// 1. Partidos guardados del equipo, de todas las competiciones.
/// 2. Datos del equipo (`lookupteam`, P0), su próximo y último partido
///    (`eventsnext`/`eventslast`, P1: de ahí salen las otras competiciones,
///    D8) y primera etapa de cada competición del índice
///    ([EnsureTeamIndex], P1): así se sabe qué competiciones juega en la
///    temporada.
/// 3. Todas las rondas de la temporada de esas competiciones, de a una
///    (P2, con cupo propio): primero las más recientes y alternando
///    competiciones. Las vigentes no generan peticiones.
///
/// Copas internacionales (Fase D6): entran si el equipo tiene partidos
/// guardados en la copa o un puntero es de ella. Primero la ronda del
/// puntero (P1); después, en orden cronológico (P2), las etapas que ya
/// empezaron y, si el puntero es posterior, hasta su etapa: las futuras se
/// piden cuando empiezan. Se dejan de pedir solo con evidencia de que el
/// equipo ya no juega ([ContinentalExitEvidence], sobre lo guardado, antes
/// de empezar y después de cada ronda); que no aparezca en una ronda nunca
/// corta.
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
    final labeler = StoredMatchLabeler(_matches, catalog: _catalog);
    Team? info;
    Failure? infoError;
    TeamPointers? pointers;

    Future<TeamDetail> build(SyncProgress progress) async {
      final stored = await _matches.storedTeamMatches(teamId);
      final season = _seasonOf(stored, today);
      final items = [
        for (final m in stored) await _teamMatch(labeler, m, season),
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
            if (!MatchGrouping.isPlayed(i.match, today)) i,
        ]..sort((a, b) => MatchGrouping.compare(a.match, b.match)),
        played: [
          for (final i in items)
            if (MatchGrouping.isPlayed(i.match, today)) i,
        ]..sort((a, b) => MatchGrouping.compare(b.match, a.match)),
        otherCompetitions: _otherCompetitions(pointers, stored),
        progress: progress,
      );
    }

    yield await build(const SyncProgress());

    final infoRequest = _loadInfo(teamId, forceRefresh);
    final pointersRequest = _loadPointers(teamId, forceRefresh);
    Failure? failure = await EnsureTeamIndex(_matches, catalog: _catalog)(
      now: now,
    );
    final bool infoFetched;
    (info, infoError, infoFetched) = await infoRequest;
    final bool pointersFetched;
    (pointers, pointersFetched) = await pointersRequest;
    if (cancelToken.isCancelled) return;

    final stored = await _matches.storedTeamMatches(teamId);
    final plan = failure != null
        ? <_Step>[]
        : await _plan(
            teamId,
            stored,
            _seasonOf(stored, today),
            today,
            forceRefresh,
            pointers,
          );
    var done = 0;
    var fetched = (infoFetched ? 1 : 0) + (pointersFetched ? 1 : 0);
    yield await build(SyncProgress(total: plan.length, fetched: fetched));

    while (done < plan.length) {
      final step = plan[done];
      try {
        final queried = await _matches.syncRound(
          step.query,
          priority: step.priority,
          forceRefresh: step.force,
          cancelToken: cancelToken,
        );
        if (queried) fetched++;
      } on SyncCancelled {
        return;
      } on Failure catch (error) {
        failure = error;
        break;
      }
      if (cancelToken.isCancelled) return;
      done++;
      labeler.invalidate(step.query);
      if (step.cup case final cup?) await _cut(teamId, cup, plan, done);
      yield await build(
        SyncProgress(done: done, total: plan.length, fetched: fetched),
      );
    }

    yield await build(
      SyncProgress(
        done: done,
        total: plan.length,
        isRunning: false,
        failure: failure,
        fetched: fetched,
      ),
    );
  }

  static Future<TeamMatch> _teamMatch(
    StoredMatchLabeler labeler,
    Match m,
    Season current,
  ) async {
    final labels = await labeler.describe(m, current: current);
    return TeamMatch(
      match: m,
      competitionName: labels.competitionName,
      phaseLabel: labels.phase,
      stageLabel: labels.stage,
    );
  }

  CompetitionDefinition? _definition(int id) =>
      _catalog.where((d) => d.id == id).firstOrNull;

  /// Datos del equipo, el error si no hay, y si se intentó la red.
  Future<(Team?, Failure?, bool)> _loadInfo(
    int teamId,
    bool forceRefresh,
  ) async {
    try {
      final result = await _teams.getTeam(teamId, forceRefresh: forceRefresh);
      // Con error de refresco también se intentó la red.
      return (
        result.data,
        null,
        result.origin == DataOrigin.remote || result.hasRefreshError,
      );
    } on Failure catch (failure) {
      return (null, failure, true);
    }
  }

  /// Próximo y último partido (cualquier competición) y si se intentó la
  /// red. Es información parcial: si falla y no hay nada guardado, la ficha
  /// sigue sin esa sección.
  Future<(TeamPointers?, bool)> _loadPointers(
    int teamId,
    bool forceRefresh,
  ) async {
    try {
      final result = await _teams.getTeamPointers(
        teamId,
        forceRefresh: forceRefresh,
        priority: forceRefresh ? SyncPriority.visible : SyncPriority.context,
      );
      return (
        result.data,
        result.origin == DataOrigin.remote || result.hasRefreshError,
      );
    } on Failure {
      return (null, true);
    }
  }

  /// Los punteros de competiciones fuera del catálogo y de copas
  /// internacionales mientras su partido no esté guardado: los de las
  /// ligas y copas argentinas ya están en próximos y disputados, con su
  /// fixture. El de una copa internacional deja de listarse cuando llega
  /// su ronda (la primera que pide la ficha, o al abrir el fixture de la
  /// copa); sigue si la temporada no tiene formato verificado.
  List<TeamMatch> _otherCompetitions(
    TeamPointers? pointers,
    List<Match> stored,
  ) {
    final seen = {for (final m in stored) m.id};
    return [
      for (final (match, label) in [
        (pointers?.next, 'Próximo partido'),
        (pointers?.last, 'Último partido'),
      ])
        if (match != null &&
            _listedAsOther(_definition(match.competitionId)) &&
            seen.add(match.id))
          TeamMatch(
            match: match,
            competitionName:
                _definition(match.competitionId)?.name ??
                (match.competitionName.isEmpty
                    ? 'Otra competición'
                    : match.competitionName),
            stageLabel: label,
          ),
    ];
  }

  static bool _listedAsOther(CompetitionDefinition? d) =>
      d == null || d.rules is ContinentalCupRules;

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

  /// Rondas a sincronizar: primero las forzadas por un refresco manual
  /// (P0) y las de los punteros en copas internacionales (P1); después las
  /// de la temporada alternando competiciones: las ligas y copas
  /// argentinas de la última a la primera; las internacionales en orden
  /// cronológico, para cortar con evidencia.
  Future<List<_Step>> _plan(
    int teamId,
    List<Match> stored,
    Season season,
    CalendarDay today,
    bool forceRefresh,
    TeamPointers? pointers,
  ) async {
    final byCompetition = <List<_Step>>[];
    final pointerSteps = <_Step>[];
    final cups = <_Cup>[];
    for (final d in _catalog) {
      final mine = [
        for (final m in stored)
          if (m.competitionId == d.id && m.season == season.apiValue) m,
      ];
      if (d.rules case final ContinentalCupRules rules) {
        final cupPointers = [
          for (final p in [pointers?.next, pointers?.last])
            if (p != null &&
                p.competitionId == d.id &&
                p.season == season.apiValue)
              p,
        ];
        final stages = rules.stagesOf(season);
        if (stages.isEmpty || (mine.isEmpty && cupPointers.isEmpty)) continue;
        // Etapas en las que se sabe que juega: el corte nunca las saltea.
        final known = ContinentalStageIndex.of(d, season, [
          ...mine,
          ...cupPointers,
        ]).values;
        final cup = _Cup(d, season, floor: known.fold(-1, _max));
        cups.add(cup);
        final started = stages.lastIndexWhere(
          (s) => s.from?.isAfter(today) == false,
        );
        final pointerRounds = {
          for (final p in cupPointers)
            if (stages.any((s) => s.apiRound == p.apiRound)) p.apiRound,
        };
        for (final r in pointerRounds) {
          pointerSteps.add(
            _Step(
              _query(d, season.apiValue, r),
              priority: SyncPriority.context,
              cup: cup,
            ),
          );
        }
        final seen = {...pointerRounds};
        byCompetition.add([
          for (final (i, s) in stages.indexed)
            if (i <= _max(started, cup.floor) && seen.add(s.apiRound))
              _Step(_query(d, season.apiValue, s.apiRound), cup: cup, stage: i),
        ]);
        continue;
      }
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
        for (final r in rounds.toList().reversed)
          _Step(_query(d, season.apiValue, r)),
      ]);
    }

    final ordered = <RoundQuery, _Step>{};
    if (forceRefresh) {
      for (final m in stored) {
        if (m.status.isFinished || !_inRefreshWindow(m, today)) continue;
        if (_definition(m.competitionId) case final d?) {
          final query = _query(d, m.season, m.apiRound);
          ordered[query] = _Step(
            query,
            priority: SyncPriority.visible,
            force: true,
          );
        }
      }
    }
    for (final step in pointerSteps) {
      ordered.putIfAbsent(step.query, () => step);
    }
    final longest = byCompetition.map((l) => l.length).fold(0, _max);
    for (var i = 0; i < longest; i++) {
      for (final steps in byCompetition) {
        if (i < steps.length) {
          ordered.putIfAbsent(steps[i].query, () => steps[i]);
        }
      }
    }
    final plan = ordered.values.toList();
    for (final cup in cups) {
      await _cut(teamId, cup, plan, 0);
    }
    return plan;
  }

  /// Saca de [plan], desde [from], las rondas de [cup] posteriores a la
  /// etapa en la que el equipo quedó afuera según lo guardado. Sin
  /// evidencia no saca nada.
  Future<void> _cut(int teamId, _Cup cup, List<_Step> plan, int from) async {
    final exit = ContinentalExitEvidence.of(
      definition: cup.definition,
      season: cup.season,
      teamId: teamId,
      matches: await _matches.storedSeason(
        cup.definition.id,
        cup.season.apiValue,
      ),
    );
    if (exit == null) return;
    final last = _max(exit.stageIndex, cup.floor);
    final kept = [
      for (final step in plan.skip(from))
        if (step.cup != cup || (step.stage ?? 0) <= last) step,
    ];
    plan
      ..removeRange(from, plan.length)
      ..addAll(kept);
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
    expectedMinimum: switch (Season.tryParse(season)) {
      final s? => d.expectedMinimumMatches(s, apiRound),
      null => null,
    },
  );

  static int _max(int a, int b) => a > b ? a : b;
}

/// Copa internacional del plan de la ficha.
final class _Cup {
  _Cup(this.definition, this.season, {required this.floor});

  final CompetitionDefinition definition;
  final Season season;

  /// Última etapa con partidos conocidos del equipo (guardados o del
  /// puntero; -1 si no hay): el corte nunca la saltea.
  final int floor;
}

/// Ronda a sincronizar en la ficha.
final class _Step {
  const _Step(
    this.query, {
    this.priority = SyncPriority.team,
    this.force = false,
    this.cup,
    this.stage,
  });

  final RoundQuery query;
  final SyncPriority priority;

  /// Refresco manual: se pide aunque esté vigente.
  final bool force;

  /// Ronda de una copa internacional: después de pedirla se revisa el
  /// corte.
  final _Cup? cup;

  /// Primera etapa de [cup] que usa la ronda; `null` en las que nunca se
  /// cortan (las de los punteros).
  final int? stage;
}
