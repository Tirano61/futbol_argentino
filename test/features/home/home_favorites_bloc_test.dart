import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:futbol_argentino/features/favorites/domain/entities/favorite_team.dart';
import 'package:futbol_argentino/features/home/domain/usecases/watch_favorite_teams.dart';
import 'package:futbol_argentino/features/home/presentation/bloc/home_favorites_bloc.dart';

import '../../helpers/fake_teams.dart';
import '../../helpers/fakes.dart';
import '../../helpers/favorites.dart';
import '../../helpers/recorded_home.dart';

void main() {
  late FavoritesRepositoryImpl favorites;
  late FakeMatchRepository matches;
  final now = DateTime.utc(2026, 10, 11, 20, 35);

  setUp(() async {
    favorites = await memoryFavorites();
    matches = FakeMatchRepository(recordedRounds());
  });

  HomeFavoritesBloc build() => HomeFavoritesBloc(
    watchFavoriteTeams: WatchFavoriteTeams(
      favorites: favorites,
      matches: matches,
    ),
    clock: FixedClock(now),
  );

  blocTest<HomeFavoritesBloc, HomeFavoritesState>(
    'sin favoritos: lista vacía',
    build: build,
    act: (bloc) => bloc.add(const HomeFavoritesStarted()),
    expect: () => [const HomeFavoritesLoaded([])],
  );

  blocTest<HomeFavoritesBloc, HomeFavoritesState>(
    'agregar un favorito lo muestra con sus partidos guardados',
    build: build,
    act: (bloc) async {
      bloc.add(const HomeFavoritesStarted());
      await bloc.stream.first;
      await favorites.save(
        FavoriteTeam.fromRef(recordedTeam('Boca Juniors'), addedAt: now),
      );
    },
    wait: const Duration(milliseconds: 50),
    verify: (bloc) {
      final state = bloc.state as HomeFavoritesLoaded;
      final boca = state.teams.single;
      expect(boca.team.name, 'Boca Juniors');
      expect(boca.next?.stageLabel, 'Fecha 13');
      expect(boca.last?.stageLabel, 'Fecha 12');
      // Sin peticiones: solo lecturas locales.
      expect(matches.calls, isEmpty);
      expect(matches.synced, isEmpty);
    },
  );
}
