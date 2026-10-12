import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:futbol_argentino/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:futbol_argentino/features/favorites/presentation/bloc/favorites_bloc.dart';
import 'package:sembast/sembast_memory.dart';

/// Favoritos reales sobre una base sembast en memoria.
Future<FavoritesRepositoryImpl> memoryFavorites() async =>
    FavoritesRepositoryImpl(
      await newDatabaseFactoryMemory().openDatabase('favorites.db'),
    );

/// El repositorio y el `FavoritesBloc` global, como en la app.
Widget withFavorites({
  required FavoritesRepository favorites,
  required Clock clock,
  required Widget child,
}) => RepositoryProvider<FavoritesRepository>.value(
  value: favorites,
  child: BlocProvider(
    create: (context) =>
        FavoritesBloc(favorites: favorites, clock: clock)
          ..add(const FavoritesSubscribed()),
    child: child,
  ),
);

/// Usa la base fuera del reloj falso de `testWidgets` (sembast usa
/// temporizadores, que solo avanzan con `pump`).
Future<T> outsideFakeAsync<T>(
  WidgetTester tester,
  Future<T> Function() body,
) async => (await tester.runAsync(body)) as T;
