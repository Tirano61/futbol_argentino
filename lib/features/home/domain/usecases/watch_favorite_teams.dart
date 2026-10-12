import 'dart:async';

import '../../../../core/time/argentina_time.dart';
import '../../../../core/time/calendar_day.dart';
import '../../../competitions/domain/catalog/competition_catalog.dart';
import '../../../competitions/domain/entities/season.dart';
import '../../../competitions/domain/services/stored_match_labeler.dart';
import '../../../favorites/domain/entities/favorite_team.dart';
import '../../../favorites/domain/repositories/favorites_repository.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../../../matches/domain/services/match_grouping.dart';
import '../entities/favorite_team_overview.dart';
import '../entities/home_feed.dart';

/// «Tus equipos» del Inicio: próximo y último partido de cada favorito.
///
/// Solo lee lo guardado (ninguna petición): se actualiza cuando cambian los
/// favoritos y cada vez que se guardan partidos (p. ej. al cargar el Inicio
/// o abrir una ficha).
class WatchFavoriteTeams {
  const WatchFavoriteTeams({
    required FavoritesRepository favorites,
    required MatchRepository matches,
    List<CompetitionDefinition> catalog = CompetitionCatalog.all,
  }) : _favorites = favorites,
       _matches = matches,
       _catalog = catalog;

  final FavoritesRepository _favorites;
  final MatchRepository _matches;
  final List<CompetitionDefinition> _catalog;

  /// [now]: hora actual (UTC), consultada en cada emisión.
  Stream<List<FavoriteTeamOverview>> call({required DateTime Function() now}) {
    StreamSubscription<List<FavoriteTeam>>? favoritesSub;
    StreamSubscription<List<FavoriteTeamOverview>>? matchesSub;
    late final StreamController<List<FavoriteTeamOverview>> controller;

    void follow(List<FavoriteTeam> teams) {
      // Cambiaron los favoritos: se dejan de seguir los partidos anteriores.
      unawaited(matchesSub?.cancel());
      matchesSub = _matches
          .watchStoredTeamsMatches({for (final t in teams) t.teamId})
          .asyncMap((stored) => _build(teams, stored, now()))
          .listen(controller.add, onError: controller.addError);
    }

    controller = StreamController(
      onListen: () => favoritesSub = _favorites.watchAll().listen(
        follow,
        onError: controller.addError,
      ),
      onCancel: () async {
        await matchesSub?.cancel();
        await favoritesSub?.cancel();
      },
    );
    return controller.stream;
  }

  Future<List<FavoriteTeamOverview>> _build(
    List<FavoriteTeam> teams,
    List<Match> stored,
    DateTime now,
  ) async {
    final today = ArgentinaTime.dayOf(now);
    final labeler = StoredMatchLabeler(_matches, catalog: _catalog);
    final current = Season(today.year);
    final all = MatchGrouping.dedupe(stored);

    Future<HomeMatch?> describe(Match? m) async {
      if (m == null) return null;
      final labels = await labeler.describe(m, current: current);
      return HomeMatch(
        match: m,
        competitionName: labels.competitionName,
        phaseLabel: labels.phase,
        stageLabel: labels.stage,
      );
    }

    final overviews = <FavoriteTeamOverview>[];
    for (final team in teams) {
      final (:next, :last) = _nextAndLast([
        for (final m in all)
          if (m.involvesTeam(team.teamId)) m,
      ], today);
      overviews.add(
        FavoriteTeamOverview(
          team: team,
          next: await describe(next),
          last: await describe(last),
        ),
      );
    }
    return overviews;
  }

  static ({Match? next, Match? last}) _nextAndLast(
    List<Match> matches,
    CalendarDay today,
  ) {
    Match? next;
    Match? last;
    for (final m in matches) {
      if (MatchGrouping.isPlayed(m, today)) {
        if (last == null || MatchGrouping.compare(m, last) > 0) last = m;
      } else if (next == null || MatchGrouping.compare(m, next) < 0) {
        next = m;
      }
    }
    return (next: next, last: last);
  }
}
