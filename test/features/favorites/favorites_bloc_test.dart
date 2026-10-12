import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:futbol_argentino/features/favorites/presentation/bloc/favorites_bloc.dart';

import '../../helpers/fake_teams.dart';
import '../../helpers/fakes.dart';
import '../../helpers/favorites.dart';

void main() {
  late FavoritesRepositoryImpl favorites;
  final now = DateTime.utc(2026, 10, 12, 15);
  final boca = recordedTeam('Boca Juniors');
  final river = recordedTeam('River Plate');

  setUp(() async => favorites = await memoryFavorites());

  FavoritesBloc build() =>
      FavoritesBloc(favorites: favorites, clock: FixedClock(now));

  List<String> names(FavoritesState s) => [for (final t in s.teams) t.name];

  blocTest<FavoritesBloc, FavoritesState>(
    'al suscribirse: lista vacía',
    build: build,
    act: (bloc) => bloc.add(const FavoritesSubscribed()),
    expect: () => [const FavoritesLoaded([])],
  );

  blocTest<FavoritesBloc, FavoritesState>(
    'tocar la estrella agrega y la lista se actualiza',
    build: build,
    act: (bloc) async {
      bloc.add(const FavoritesSubscribed());
      await bloc.stream.first;
      bloc
        ..add(FavoriteToggled(river))
        ..add(FavoriteToggled(boca));
    },
    wait: const Duration(milliseconds: 50),
    verify: (bloc) {
      expect(names(bloc.state), ['Boca Juniors', 'River Plate']);
      expect(bloc.state.contains(boca.id), isTrue);
      expect(bloc.state.teams.first.addedAt, now);
    },
  );

  blocTest<FavoritesBloc, FavoritesState>(
    'dos toques seguidos agregan y quitan (en orden, sin esperar la lista)',
    build: build,
    act: (bloc) async {
      bloc.add(const FavoritesSubscribed());
      await bloc.stream.first;
      bloc
        ..add(FavoriteToggled(boca))
        ..add(FavoriteToggled(boca));
    },
    wait: const Duration(milliseconds: 50),
    verify: (bloc) async {
      expect(bloc.state.teams, isEmpty);
      expect(await favorites.contains(boca.id), isFalse);
    },
  );
}
