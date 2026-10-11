import 'dart:async';

import '../../../../core/error/failure.dart';
import '../../../../core/result/data_result.dart';
import '../../../../core/sync/sync_scheduler.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../../core/time/calendar_day.dart';
import '../../../competitions/domain/catalog/competition_catalog.dart';
import '../../../competitions/domain/entities/phase_assignment.dart';
import '../../../competitions/domain/entities/season.dart';
import '../../../competitions/domain/repositories/competition_repository.dart';
import '../../../competitions/domain/services/phase_resolver.dart';
import '../../../competitions/domain/services/round_navigator.dart';
import '../../../competitions/domain/services/stage_labeler.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../entities/home_feed.dart';

/// Partidos del Inicio: de ayer a 7 días, de todas las competiciones del
/// catálogo.
///
/// Por competición consulta el próximo y el último partido y, como mucho,
/// dos rondas ([roundsFor]). Los partidos de los punteros se muestran
/// aunque su ronda no se cargue (p. ej. uno reprogramado de una fecha
/// anterior). En frío: 3 × 2 punteros + ≤ 6 rondas = ≤ 12 peticiones; con
/// todo vigente, ninguna.
///
/// Emite un [HomeFeed] cada vez que llega algo, sin esperar al resto: lo
/// guardado aparece enseguida y cada competición se completa por su cuenta.
/// Un error de una competición no afecta a las demás.
class GetHomeFeed {
  const GetHomeFeed({
    required CompetitionRepository competitions,
    required MatchRepository matches,
    List<CompetitionDefinition> catalog = CompetitionCatalog.all,
  }) : _competitions = competitions,
       _matches = matches,
       _catalog = catalog;

  final CompetitionRepository _competitions;
  final MatchRepository _matches;
  final List<CompetitionDefinition> _catalog;

  static const daysBack = 1;
  static const daysAhead = 7;
  static const maxRoundsPerCompetition = 2;

  /// [forceRefresh]: refresco manual (ignora la vigencia y va con prioridad
  /// P0). Si no, las consultas son de contexto (P1).
  Stream<HomeFeed> call({required DateTime now, bool forceRefresh = false}) {
    final today = ArgentinaTime.dayOf(now);
    final feeds = {
      for (final d in _catalog) d.id: CompetitionFeed(competition: d),
    };
    final subscriptions = <StreamSubscription<void>>[];
    var cancelled = false;
    late final StreamController<HomeFeed> controller;

    void publish([CompetitionFeed? feed]) {
      if (cancelled) return;
      if (feed != null) feeds[feed.competition.id] = feed;
      controller.add(HomeFeed(today: today, competitions: [...feeds.values]));
    }

    controller = StreamController<HomeFeed>(
      onListen: () {
        publish();
        final load = _Load(
          window: (
            from: today.addDays(-daysBack),
            to: today.addDays(daysAhead),
          ),
          forceRefresh: forceRefresh,
          priority: forceRefresh ? SyncPriority.visible : SyncPriority.context,
          publish: publish,
          fail: controller.addError,
          subscriptions: subscriptions,
          isCancelled: () => cancelled,
        );
        Future.wait([
          for (final d in _catalog) _loadCompetition(d, load),
        ]).whenComplete(() {
          if (!cancelled) controller.close();
        });
      },
      onCancel: () async {
        cancelled = true;
        await Future.wait([for (final s in subscriptions) s.cancel()]);
      },
    );
    return controller.stream;
  }

  /// Rondas a consultar: la del último partido y la etapa siguiente; si no
  /// hay último partido o no hay etapa siguiente, la del próximo partido y
  /// la siguiente a esa. Como mucho [maxRoundsPerCompetition].
  ///
  /// Cubre la fecha en curso (próximo y último en la misma ronda), el
  /// cambio de fecha (el próximo ya en la siguiente) y la copa (códigos no
  /// consecutivos).
  static List<RoundQuery> roundsFor(
    CompetitionDefinition definition,
    SchedulePointers pointers,
  ) {
    final rounds = <RoundQuery>[];
    void add(RoundQuery? query) {
      if (query != null &&
          !rounds.contains(query) &&
          rounds.length < maxRoundsPerCompetition) {
        rounds.add(query);
      }
    }

    for (final m in [pointers.last, pointers.next].nonNulls) {
      add(_query(definition, m.season, m.apiRound));
      add(_followingRound(definition, m));
    }
    return rounds;
  }

  /// La ronda de la etapa siguiente a la del partido (salteando etapas de
  /// la misma ronda, como los octavos dentro de la ronda 16 de Primera).
  static RoundQuery? _followingRound(
    CompetitionDefinition definition,
    Match match,
  ) {
    final located = RoundNavigator.locate(definition, match);
    if (located == null) return null;
    final following = located.stages
        .skip(located.stages.indexOf(located.stage) + 1)
        .where((s) => s.apiRound != match.apiRound)
        .firstOrNull;
    return following == null
        ? null
        : _query(definition, following.season.apiValue, following.apiRound);
  }

  static RoundQuery _query(
    CompetitionDefinition definition,
    String season,
    int apiRound,
  ) => RoundQuery(
    competitionId: definition.id,
    season: season,
    apiRound: apiRound,
    expectedMinimum: definition.expectedMinimumMatches(apiRound),
  );

  Future<void> _loadCompetition(
    CompetitionDefinition definition,
    _Load load,
  ) async {
    final DataResult<SchedulePointers> pointers;
    try {
      pointers = await _competitions.getSchedulePointers(
        definition.id,
        forceRefresh: load.forceRefresh,
        priority: load.priority,
      );
    } on Failure catch (failure) {
      load.publish(
        CompetitionFeed(
          competition: definition,
          isLoading: false,
          error: failure,
        ),
      );
      return;
    }
    if (load.isCancelled()) return;

    final queries = roundsFor(definition, pointers.data);
    final results = <RoundQuery, DataResult<List<Match>>>{};
    Failure? roundFailure;
    var pending = queries.length;

    void publish() => load.publish(
      _build(
        definition,
        load,
        pointers: pointers,
        rounds: results,
        roundFailure: roundFailure,
        isLoading: pending > 0,
      ),
    );

    publish();
    await Future.wait([
      for (final query in queries)
        () {
          final done = Completer<void>();
          load.subscriptions.add(
            _matches
                .watchRound(
                  query,
                  forceRefresh: load.forceRefresh,
                  priority: load.priority,
                )
                .listen(
                  (result) {
                    results[query] = result;
                    publish();
                  },
                  onError: (Object error, StackTrace stackTrace) {
                    // Sin datos guardados de la ronda y sin red.
                    if (error is Failure) {
                      roundFailure ??= error;
                    } else {
                      load.fail(error, stackTrace);
                    }
                  },
                  onDone: () {
                    pending--;
                    publish();
                    done.complete();
                  },
                ),
          );
          return done.future;
        }(),
    ]);
  }

  CompetitionFeed _build(
    CompetitionDefinition definition,
    _Load load, {
    required DataResult<SchedulePointers> pointers,
    required Map<RoundQuery, DataResult<List<Match>>> rounds,
    required Failure? roundFailure,
    required bool isLoading,
  }) {
    final resolver = PhaseResolver(definition);
    final items = <HomeMatch>[];
    final inRounds = <int>{};
    var fetchedAt = pointers.fetchedAt;
    var error = pointers.refreshError;

    for (final MapEntry(key: query, value: result) in rounds.entries) {
      if (result.fetchedAt.isBefore(fetchedAt)) fetchedAt = result.fetchedAt;
      error ??= result.refreshError;
      final season = Season.tryParse(query.season);
      // La fase necesita la ronda completa (consistencia e inferencia).
      final assigned = season == null
          ? const <int, PhaseAssignment>{}
          : resolver.classifyRound(
              season: season,
              apiRound: query.apiRound,
              matches: result.data,
            );
      for (final m in result.data) {
        inRounds.add(m.id);
        if (load.contains(m)) {
          items.add(_homeMatch(definition, m, assigned[m.id]));
        }
      }
    }

    for (final m in [pointers.data.last, pointers.data.next].nonNulls) {
      if (!inRounds.contains(m.id) && m.isVisible && load.contains(m)) {
        inRounds.add(m.id);
        items.add(_homeMatch(definition, m, null));
      }
    }

    return CompetitionFeed(
      competition: definition,
      isLoading: isLoading,
      matches: items,
      fetchedAt: fetchedAt,
      error: error ?? roundFailure,
    );
  }

  /// [assignment]: fase calculada con la ronda completa; si no hay, se
  /// clasifica el partido solo.
  HomeMatch _homeMatch(
    CompetitionDefinition definition,
    Match match,
    PhaseAssignment? assignment,
  ) {
    final season = Season.tryParse(match.season);
    final phase =
        assignment ??
        (season == null
            ? const PhaseAssignment.undetermined()
            : PhaseResolver(definition).classifyRound(
                season: season,
                apiRound: match.apiRound,
                matches: [match],
              )[match.id]!);
    final determined = phase.isDetermined;
    return HomeMatch(
      match: match,
      competitionName: definition.name,
      phaseLabel: determined && definition.phases.length > 1
          ? phase.phase.label
          : null,
      stageLabel: determined
          ? StageLabeler.label(definition, match.apiRound, phase.stageKind)
          : 'Ronda ${match.apiRound}',
    );
  }
}

/// Parámetros compartidos de una carga del Inicio.
final class _Load {
  const _Load({
    required this.window,
    required this.forceRefresh,
    required this.priority,
    required this.publish,
    required this.fail,
    required this.subscriptions,
    required this.isCancelled,
  });

  final ({CalendarDay from, CalendarDay to}) window;
  final bool forceRefresh;
  final SyncPriority priority;
  final void Function(CompetitionFeed feed) publish;
  final void Function(Object error, StackTrace stackTrace) fail;
  final List<StreamSubscription<void>> subscriptions;
  final bool Function() isCancelled;

  /// El partido cae entre ayer y dentro de 7 días (día argentino).
  bool contains(Match match) {
    final day = match.kickoff.argentinaDay;
    return day != null && !day.isBefore(window.from) && !day.isAfter(window.to);
  }
}
