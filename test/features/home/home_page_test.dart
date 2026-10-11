import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/competitions/domain/repositories/competition_repository.dart';
import 'package:futbol_argentino/features/home/presentation/pages/home_page.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fakes.dart';
import '../../helpers/recorded_home.dart';

const offline = NetworkFailure(
  issue: NetworkIssue.connection,
  detail: 'Failed host lookup',
);

FakeCompetitionRepository recordedCompetitions({
  Map<int, Failure> failures = const {},
}) => FakeCompetitionRepository(
  pointersById: {
    for (final d in CompetitionCatalog.all) d.id: recordedPointers(d.id),
  },
  failuresById: failures,
);

Future<void> pumpHome(
  WidgetTester tester, {
  FakeMatchRepository? matches,
  FakeCompetitionRepository? competitions,
  bool showDiagnostics = false,
}) async {
  tester.view
    ..physicalSize = const Size(900, 12000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  Widget placeholder(String text) => Scaffold(body: Text(text));
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => HomePage(showDiagnostics: showDiagnostics),
      ),
      GoRoute(
        path: '/equipos',
        builder: (context, state) => placeholder('Pantalla de equipos'),
      ),
      GoRoute(
        path: '/competiciones/:id',
        builder: (context, state) =>
            placeholder('Fixture ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/partidos/:id',
        builder: (context, state) =>
            placeholder('Partido ${state.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<MatchRepository>.value(
          value: matches ?? FakeMatchRepository(recordedRounds()),
        ),
        RepositoryProvider<CompetitionRepository>.value(
          value: competitions ?? recordedCompetitions(),
        ),
        // Domingo 11/10/2026, 17:00 en Argentina.
        RepositoryProvider<Clock>.value(
          value: FixedClock(DateTime.utc(2026, 10, 11, 20)),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Hoy, Próximos y Recientes con datos reales', (tester) async {
    await pumpHome(tester);

    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Domingo 11/10/2026'), findsOneWidget);
    expect(find.text('Próximos 7 días'), findsOneWidget);
    expect(find.text('Recientes'), findsOneWidget);
    // 17 de hoy + 37 próximos + 8 de ayer.
    expect(find.byType(MatchCard), findsNWidgets(62));
    expect(find.text('Sábado 10/10/2026'), findsOneWidget);
    expect(find.text('Domingo 18/10/2026'), findsOneWidget);
    expect(find.text('Primera División · Clausura · Fecha 12'), findsWidgets);
    expect(find.text('Primera Nacional · Fecha 34'), findsNWidgets(18));
    expect(find.textContaining('Horarios de Argentina'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('los accesos llevan a cada fixture', (tester) async {
    await pumpHome(tester);

    for (final d in CompetitionCatalog.all) {
      expect(find.widgetWithText(ActionChip, d.name), findsOneWidget);
    }
    await tester.tap(find.widgetWithText(ActionChip, 'Copa Argentina'));
    await tester.pumpAndSettle();

    expect(find.text('Fixture 4500'), findsOneWidget);
  });

  testWidgets('el acceso al buscador abre Equipos', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('Buscar equipo'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla de equipos'), findsOneWidget);
  });

  testWidgets('tocar un partido abre su detalle', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const ValueKey(2398124)));
    await tester.pumpAndSettle();

    expect(find.text('Partido 2398124'), findsOneWidget);
  });

  testWidgets('sin partidos en la ventana: mensajes por sección', (
    tester,
  ) async {
    await pumpHome(
      tester,
      matches: FakeMatchRepository(const {}),
      competitions: FakeCompetitionRepository(),
    );

    expect(find.text('No hay partidos hoy.'), findsOneWidget);
    expect(
      find.text('No hay partidos en los próximos 7 días.'),
      findsOneWidget,
    );
    expect(find.text('No hubo partidos ayer.'), findsOneWidget);
    expect(find.byType(MatchCard), findsNothing);
  });

  testWidgets('una competición sin datos: aviso y el resto visible', (
    tester,
  ) async {
    await pumpHome(
      tester,
      competitions: recordedCompetitions(failures: {4406: offline}),
    );

    expect(find.text('No se pudo cargar: Primera División.'), findsOneWidget);
    expect(find.text('Primera Nacional · Fecha 33'), findsWidgets);
    expect(find.textContaining('Primera División ·'), findsNothing);
  });

  testWidgets('datos guardados con error: aviso de datos guardados', (
    tester,
  ) async {
    await pumpHome(
      tester,
      matches: FakeMatchRepository(recordedRounds(), refreshError: offline),
    );

    expect(find.textContaining('Mostrando datos guardados'), findsOneWidget);
    expect(find.byType(MatchCard), findsNWidgets(62));
  });

  testWidgets('sin red y sin nada guardado: error con reintento', (
    tester,
  ) async {
    await pumpHome(
      tester,
      competitions: FakeCompetitionRepository(failure: offline),
    );

    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byType(MatchCard), findsNothing);
  });

  testWidgets('«Actualizar» fuerza la consulta', (tester) async {
    final competitions = recordedCompetitions();
    await pumpHome(tester, competitions: competitions);

    // El cierre del stream de la carga inicial se agenda fuera de la zona
    // de FakeAsync: una vuelta real del event loop deja terminar al handler
    // (si no, `droppable` descarta el refresco).
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();

    expect(competitions.pointerCalls.where((c) => c.force), hasLength(3));
    expect(find.byType(MatchCard), findsNWidgets(62));
  });

  testWidgets('acceso al diagnóstico solo si está habilitado', (tester) async {
    await pumpHome(tester);
    expect(find.byTooltip('Diagnóstico de la API'), findsNothing);

    await pumpHome(tester, showDiagnostics: true);
    expect(find.byTooltip('Diagnóstico de la API'), findsOneWidget);
  });
}
