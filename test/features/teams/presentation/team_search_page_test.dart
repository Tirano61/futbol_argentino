import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:futbol_argentino/features/teams/domain/repositories/team_repository.dart';
import 'package:futbol_argentino/features/teams/presentation/pages/team_search_page.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/fake_teams.dart';
import '../../../helpers/favorites.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/fixture_matches.dart';

const offline = NetworkFailure(
  issue: NetworkIssue.connection,
  detail: 'Failed host lookup',
);

Future<void> pumpSearch(
  WidgetTester tester, {
  required FakeTeamRepository teams,
  FakeMatchRepository? matches,
  FavoritesRepository? favorites,
  String initialQuery = '',
}) async {
  final clock = FixedClock(DateTime.utc(2026, 10, 11, 20));
  final router = GoRouter(
    initialLocation: '/equipos',
    routes: [
      GoRoute(
        path: '/equipos',
        builder: (context, state) => TeamSearchPage(initialQuery: initialQuery),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                Scaffold(body: Text('Equipo ${state.pathParameters['id']}')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TeamRepository>.value(value: teams),
        RepositoryProvider<MatchRepository>.value(
          value:
              matches ??
              FakeMatchRepository({
                1: fixtureMatches('eventsround_4406_r1_s2026'),
                64: fixtureMatches('eventsround_4500_r64_s2026'),
              }),
        ),
        RepositoryProvider<Clock>.value(value: clock),
      ],
      child: withFavorites(
        favorites: favorites ?? await outsideFakeAsync(tester, memoryFavorites),
        clock: clock,
        child: MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pump();
}

Future<void> type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  // Debounce de 350 ms.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  testWidgets('sin búsqueda: invita a buscar y cuenta los equipos', (
    tester,
  ) async {
    await pumpSearch(
      tester,
      teams: FakeTeamRepository(stored: recordedTeamSummaries()),
    );

    expect(find.text('Buscá un equipo'), findsOneWidget);
    expect(find.textContaining('Probá con «river»'), findsOneWidget);
  });

  testWidgets('«boca»: Boca Juniors con sus competiciones; abre la ficha', (
    tester,
  ) async {
    await pumpSearch(
      tester,
      teams: FakeTeamRepository(stored: recordedTeamSummaries()),
    );

    await type(tester, 'boca');

    expect(find.text('Boca Juniors'), findsOneWidget);
    expect(find.text('Primera División · Copa Argentina'), findsOneWidget);

    await tester.tap(find.text('Boca Juniors'));
    await tester.pumpAndSettle();
    expect(find.text('Equipo 135156'), findsOneWidget);
  });

  testWidgets('la estrella de un resultado lo agrega a favoritos', (
    tester,
  ) async {
    final favorites = await outsideFakeAsync(tester, memoryFavorites);
    await pumpSearch(
      tester,
      teams: FakeTeamRepository(stored: recordedTeamSummaries()),
      favorites: favorites,
    );
    await tester.pumpAndSettle();
    await type(tester, 'river');

    await tester.tap(find.byTooltip('Agregar a favoritos'));
    await tester.pumpAndSettle();

    expect(find.text('River Plate se agregó a favoritos'), findsOneWidget);
    expect(find.byTooltip('Quitar de favoritos'), findsOneWidget);
    final stored = await outsideFakeAsync(
      tester,
      () => favorites.watchAll().first,
    );
    expect(stored.single.ref, recordedTeam('River Plate'));
  });

  testWidgets('mientras espera el debounce no vuelve a invitar a buscar', (
    tester,
  ) async {
    await pumpSearch(
      tester,
      teams: FakeTeamRepository(stored: recordedTeamSummaries()),
    );

    await tester.enterText(find.byType(TextField), 'riv');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Buscá un equipo'), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('River Plate'), findsOneWidget);
  });

  testWidgets('competiciones en el orden del catálogo', (tester) async {
    await pumpSearch(
      tester,
      teams: FakeTeamRepository(stored: recordedTeamSummaries()),
    );

    await type(tester, 'gimnasia jujuy');

    expect(find.text('Primera Nacional · Copa Argentina'), findsOneWidget);
  });

  testWidgets('el botón de borrar vuelve al inicio del buscador', (
    tester,
  ) async {
    await pumpSearch(
      tester,
      teams: FakeTeamRepository(stored: recordedTeamSummaries()),
    );
    await type(tester, 'river');
    expect(find.text('River Plate'), findsOneWidget);

    await tester.tap(find.byTooltip('Borrar búsqueda'));
    await tester.pump();

    expect(find.text('River Plate'), findsNothing);
    expect(find.text('Buscá un equipo'), findsOneWidget);
  });

  testWidgets('resultado en línea con su aviso', (tester) async {
    await pumpSearch(
      tester,
      teams: FakeTeamRepository(
        stored: recordedTeamSummaries(),
        online: {'boca unidos': recordedTeams('searchteams_Boca')},
      ),
    );

    await type(tester, 'boca unidos');

    expect(find.textContaining('Resultados de TheSportsDB'), findsOneWidget);
    expect(find.text('Boca Unidos'), findsOneWidget);
  });

  testWidgets('sin coincidencias y sin red: lo dice', (tester) async {
    await pumpSearch(
      tester,
      teams: FakeTeamRepository(
        stored: recordedTeamSummaries(),
        onlineFailure: offline,
      ),
    );

    await type(tester, 'xyzw');

    expect(find.text('No se encontraron equipos'), findsOneWidget);
    expect(find.textContaining('Sin conexión'), findsOneWidget);
  });

  testWidgets('sin equipos guardados ni red: avisa que no cargó la lista', (
    tester,
  ) async {
    await pumpSearch(
      tester,
      teams: FakeTeamRepository(onlineFailure: offline),
      matches: FakeMatchRepository(const {}, failure: offline),
    );
    await tester.pump();

    expect(
      find.textContaining('No se pudo cargar la lista de equipos'),
      findsOneWidget,
    );
  });

  testWidgets('búsqueda inicial desde la URL', (tester) async {
    await pumpSearch(
      tester,
      teams: FakeTeamRepository(stored: recordedTeamSummaries()),
      initialQuery: 'velez',
    );
    await tester.pump();

    expect(find.text('Vélez Sarsfield'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'velez',
    );
  });
}
