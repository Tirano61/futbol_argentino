import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:futbol_argentino/features/favorites/domain/entities/favorite_team.dart';
import 'package:futbol_argentino/features/favorites/presentation/pages/favorites_page.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_teams.dart';
import '../../helpers/fakes.dart';
import '../../helpers/favorites.dart';

Future<void> pumpFavorites(
  WidgetTester tester,
  FavoritesRepositoryImpl favorites,
) async {
  Widget placeholder(String text) => Scaffold(body: Text(text));
  final router = GoRouter(
    initialLocation: '/favoritos',
    routes: [
      GoRoute(
        path: '/favoritos',
        builder: (context, state) => const FavoritesPage(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                placeholder('Equipo ${state.pathParameters['id']}'),
          ),
        ],
      ),
      GoRoute(
        path: '/equipos',
        builder: (context, state) => placeholder('Pantalla de equipos'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    withFavorites(
      favorites: favorites,
      clock: FixedClock(DateTime.utc(2026, 10, 12, 15)),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> save(FavoritesRepositoryImpl favorites, String name) =>
    favorites.save(
      FavoriteTeam.fromRef(
        recordedTeam(name),
        addedAt: DateTime.utc(2026, 10, 12),
      ),
    );

void main() {
  testWidgets('sin favoritos: invita a buscar', (tester) async {
    await pumpFavorites(
      tester,
      await outsideFakeAsync(tester, memoryFavorites),
    );

    expect(find.text('Todavía no tenés equipos favoritos'), findsOneWidget);
    await tester.tap(find.text('Buscar equipo'));
    await tester.pumpAndSettle();
    expect(find.text('Pantalla de equipos'), findsOneWidget);
  });

  testWidgets('lista por nombre y abre la ficha dentro de Favoritos', (
    tester,
  ) async {
    final favorites = await outsideFakeAsync(tester, memoryFavorites);
    await outsideFakeAsync(tester, () => save(favorites, 'River Plate'));
    await outsideFakeAsync(tester, () => save(favorites, 'Atlético Tucumán'));
    await pumpFavorites(tester, favorites);

    final names = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title! as Text).data);
    expect(names, ['Atlético Tucumán', 'River Plate']);
    expect(find.byTooltip('Quitar de favoritos'), findsNWidgets(2));
    expect(find.text('Guardados solo en este dispositivo'), findsOneWidget);

    await tester.tap(find.text('River Plate'));
    await tester.pumpAndSettle();
    expect(
      find.text('Equipo ${recordedTeam('River Plate').id}'),
      findsOneWidget,
    );
  });

  testWidgets('quitar con la estrella y deshacer', (tester) async {
    final favorites = await outsideFakeAsync(tester, memoryFavorites);
    await outsideFakeAsync(tester, () => save(favorites, 'Boca Juniors'));
    await pumpFavorites(tester, favorites);

    await tester.tap(find.byTooltip('Quitar de favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('Boca Juniors se quitó de favoritos'), findsOneWidget);
    expect(find.text('Todavía no tenés equipos favoritos'), findsOneWidget);
    expect(
      await outsideFakeAsync(
        tester,
        () => favorites.contains(recordedTeam('Boca Juniors').id),
      ),
      isFalse,
    );

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Boca Juniors'), findsOneWidget);
    expect(
      await outsideFakeAsync(
        tester,
        () => favorites.contains(recordedTeam('Boca Juniors').id),
      ),
      isTrue,
    );
  });
}
