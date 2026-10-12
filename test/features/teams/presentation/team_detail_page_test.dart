import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:futbol_argentino/features/teams/domain/repositories/team_repository.dart';
import 'package:futbol_argentino/features/teams/presentation/pages/team_detail_page.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/fake_teams.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/fixture_matches.dart';

const bocaId = 135156;
const offline = NetworkFailure(
  issue: NetworkIssue.connection,
  detail: 'Failed host lookup',
);

FakeMatchRepository primera2026({Failure? failure}) => FakeMatchRepository({
  for (var r = 0; r <= 16; r++)
    r: fixtureMatches('eventsround_4406_r${r}_s2026'),
}, failure: failure);

FakeTeamRepository boca({Failure? failure}) => FakeTeamRepository(
  teams: {bocaId: recordedTeams('lookupteam_135156').single},
  teamFailure: failure,
);

Future<void> pumpDetail(
  WidgetTester tester, {
  required FakeMatchRepository matches,
  required FakeTeamRepository teams,
}) async {
  tester.view
    ..physicalSize = const Size(900, 6000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/equipos/$bocaId',
    routes: [
      GoRoute(
        path: '/equipos/:id',
        builder: (context, state) =>
            TeamDetailPage(teamId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/partidos/:id',
        builder: (context, state) =>
            Scaffold(body: Text('Partido ${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<MatchRepository>.value(value: matches),
        RepositoryProvider<TeamRepository>.value(value: teams),
        // Domingo 11/10/2026, 17:35 en Argentina.
        RepositoryProvider<Clock>.value(
          value: FixedClock(DateTime.utc(2026, 10, 11, 20, 35)),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('encabezado, competiciones y secciones', (tester) async {
    await pumpDetail(tester, matches: primera2026(), teams: boca());

    expect(find.text('Boca Juniors'), findsWidgets);
    expect(
      find.text('Estadio Alberto José Armando · La Boca, Buenos Aires'),
      findsOneWidget,
    );
    expect(find.widgetWithText(Chip, 'Primera División'), findsOneWidget);
    expect(find.text('Próximos'), findsOneWidget);
    expect(find.text('Disputados'), findsOneWidget);
    expect(find.text('Primera División · Clausura · Fecha 13'), findsOneWidget);
    expect(find.text('Primera División · Clausura · Fecha 12'), findsOneWidget);
    // Terminó la descarga: sin barra de progreso.
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('el más reciente de los disputados va primero', (tester) async {
    await pumpDetail(tester, matches: primera2026(), teams: boca());

    final played = tester.getTopLeft(find.text('Disputados')).dy;
    final fecha12 = tester
        .getTopLeft(find.text('Primera División · Clausura · Fecha 12'))
        .dy;
    final fecha11 = tester
        .getTopLeft(find.text('Primera División · Clausura · Fecha 11'))
        .dy;
    expect(played < fecha12 && fecha12 < fecha11, isTrue);
  });

  testWidgets('tocar un partido abre su detalle', (tester) async {
    await pumpDetail(tester, matches: primera2026(), teams: boca());

    await tester.tap(find.text('Primera División · Clausura · Fecha 13'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Partido '), findsOneWidget);
  });

  testWidgets('sin red con datos guardados: aviso con reintento', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      matches: primera2026(failure: offline),
      teams: boca(failure: offline),
    );

    expect(find.text('Boca Juniors'), findsWidgets);
    expect(find.textContaining('No se pudieron completar'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('sin datos ni red: pantalla de error', (tester) async {
    await pumpDetail(
      tester,
      matches: FakeMatchRepository(const {}, failure: offline),
      teams: boca(failure: offline),
    );

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('equipo sin partidos en la app', (tester) async {
    await pumpDetail(
      tester,
      matches: FakeMatchRepository(const {}),
      teams: boca(),
    );

    expect(
      find.text(
        'No hay partidos de este equipo en las competiciones de la app.',
      ),
      findsOneWidget,
    );
  });
}
