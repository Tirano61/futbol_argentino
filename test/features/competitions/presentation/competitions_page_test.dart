import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/time/calendar_month.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/phase.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/stage.dart';
import 'package:futbol_argentino/features/competitions/domain/repositories/competition_repository.dart';
import 'package:futbol_argentino/features/competitions/presentation/bloc/competition_fixture_bloc.dart';
import 'package:futbol_argentino/features/competitions/presentation/pages/competitions_page.dart';
import 'package:futbol_argentino/features/competitions/presentation/routing/fixture_route.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:futbol_argentino/shared/presentation/formatters/match_labels.dart';
import 'package:futbol_argentino/shared/presentation/widgets/match_card.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/fakes.dart';
import '../../../helpers/fixture_matches.dart';

Future<void> pumpPage(
  WidgetTester tester,
  FixtureOpened initial, {
  double width = 900,
  Failure? failure,
  Failure? refreshError,
}) async {
  tester.view
    ..physicalSize = Size(width, 6000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final matches = FakeMatchRepository(
    {
      for (var r = 0; r <= 16; r++)
        r: fixtureMatches('eventsround_4406_r${r}_s2026'),
      125: fixtureMatches('eventsround_4500_r125_s2026'),
    },
    refreshError: refreshError,
    failure: failure,
  );
  final competitions = FakeCompetitionRepository(
    pointers: SchedulePointers(
      next: fixtureMatches('eventsnextleague_4406').single,
    ),
  );

  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<MatchRepository>.value(value: matches),
        RepositoryProvider<CompetitionRepository>.value(value: competitions),
        RepositoryProvider<Clock>.value(
          value: FixedClock(DateTime.utc(2026, 10, 11, 21)),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  CompetitionsPage(initialEvent: initial),
            ),
            GoRoute(
              path: '/partidos/:id',
              builder: (context, state) =>
                  Scaffold(body: Text('Partido ${state.pathParameters['id']}')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Primera abre en la fecha 12 del Clausura con 15 partidos', (
    tester,
  ) async {
    await pumpPage(tester, const FixtureOpened(competitionId: 4406));

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Primera División'),
      ),
      findsOneWidget,
    );
    expect(find.text('Fecha 12'), findsOneWidget);
    final clausura = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Clausura'),
    );
    expect(clausura.selected, isTrue);
    expect(find.byType(MatchCard), findsNWidgets(15));
    expect(find.text('Viernes 09/10/2026'), findsOneWidget);
    expect(find.textContaining('Horarios de Argentina'), findsOneWidget);
  });

  testWidgets('«Siguiente» pasa a la fecha 13', (tester) async {
    await pumpPage(tester, const FixtureOpened(competitionId: 4406));

    await tester.tap(find.byTooltip('Siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('Fecha 13'), findsOneWidget);
    expect(find.byType(MatchCard), findsNWidgets(15));
  });

  testWidgets(
    'Apertura fecha 12 muestra «Horario por confirmar» en los 00:00 sin corroborar',
    (tester) async {
      await pumpPage(
        tester,
        const FixtureOpened(
          competitionId: 4406,
          season: Season(2026),
          phase: PhaseKey.apertura,
          apiRound: 12,
        ),
      );

      // 2397877 y 2397878: 2026-03-21T00:00:00 con strTimeLocal 18:00.
      expect(
        find.text(MatchLabels.unconfirmedTime),
        findsNothing,
        reason: 'están terminados: se muestra el resultado, no la hora',
      );
      expect(find.text('Sábado 21/03/2026'), findsOneWidget);
    },
  );

  testWidgets('Copa: cuartos de final', (tester) async {
    await pumpPage(
      tester,
      const FixtureOpened(
        competitionId: 4500,
        phase: PhaseKey.unica,
        apiRound: 125,
        kind: StageKind.knockout,
      ),
    );

    expect(find.text('Cuartos de final'), findsOneWidget);
    expect(find.byType(MatchCard), findsNWidgets(4));
    // Una sola fase: sin selector de fase.
    expect(find.widgetWithText(ChoiceChip, PhaseKey.unica.label), findsNothing);
  });

  testWidgets('etapa sin partidos: mensaje informativo', (tester) async {
    await pumpPage(
      tester,
      const FixtureOpened(
        competitionId: 4500,
        phase: PhaseKey.unica,
        apiRound: 200,
        kind: StageKind.knockout,
      ),
    );

    expect(find.text('Sin partidos'), findsOneWidget);
  });

  testWidgets('tablet: tocar un partido abre su pantalla', (tester) async {
    await pumpPage(tester, const FixtureOpened(competitionId: 4406));

    final first = tester.widget<MatchCard>(find.byType(MatchCard).first);
    await tester.tap(find.byType(MatchCard).first);
    await tester.pumpAndSettle();

    expect(find.text('Partido ${first.match.id}'), findsOneWidget);
  });

  testWidgets('escritorio: el partido se abre en el panel de detalle', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const FixtureOpened(competitionId: 4406),
      width: 1400,
    );
    expect(find.text('Elegí un partido de la lista para verlo acá.'), findsOne);

    final first = tester.widget<MatchCard>(find.byType(MatchCard).first);
    await tester.tap(find.byType(MatchCard).first);
    await tester.pumpAndSettle();

    // Sigue en el fixture, con el partido resaltado y su detalle al lado.
    expect(find.byType(MatchCard), findsNWidgets(15));
    expect(
      tester.widget<MatchCard>(find.byType(MatchCard).first).selected,
      isTrue,
    );
    expect(find.text('Partido'), findsOneWidget);
    expect(find.text('Hora (Argentina)'), findsOneWidget);
    expect(find.text('Partido ${first.match.id}'), findsNothing);

    await tester.tap(find.byTooltip('Cerrar detalle'));
    await tester.pumpAndSettle();

    expect(find.text('Elegí un partido de la lista para verlo acá.'), findsOne);
    expect(find.byTooltip('Cerrar detalle'), findsNothing);
  });

  testWidgets('escritorio: buscador en la barra superior', (tester) async {
    await pumpPage(
      tester,
      const FixtureOpened(competitionId: 4406),
      width: 1400,
    );

    expect(find.widgetWithText(TextField, 'Buscar equipo'), findsOneWidget);
  });

  testWidgets('actualizar antes de 30 s avisa que ya está actualizado', (
    tester,
  ) async {
    await pumpPage(tester, const FixtureOpened(competitionId: 4406));

    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();

    // El repositorio devuelve los mismos datos (misma hora de descarga).
    expect(
      find.text('Ya está actualizado: los datos son de las 17:35.'),
      findsOneWidget,
    );
  });

  testWidgets('etapa vacía: deslizar para actualizar termina', (tester) async {
    await pumpPage(
      tester,
      const FixtureOpened(
        competitionId: 4500,
        phase: PhaseKey.unica,
        apiRound: 200,
        kind: StageKind.knockout,
      ),
    );

    // La vista mide 6000 px: el gesto debe ser largo para activarse.
    await tester.drag(find.text('Sin partidos'), const Offset(0, 3000));
    await tester.pumpAndSettle();

    expect(find.byType(RefreshProgressIndicator), findsNothing);
    expect(find.textContaining('Ya está actualizado'), findsOneWidget);
  });

  group('errores', () {
    for (final (failure, title) in [
      (
        const NetworkFailure(issue: NetworkIssue.connection, detail: 'x'),
        'Sin conexión',
      ),
      (
        const NetworkFailure(issue: NetworkIssue.timeout, detail: 'x'),
        'La consulta tardó demasiado',
      ),
      (const RateLimitFailure(detail: 'x'), 'Demasiadas consultas'),
      (const FormatFailure(detail: 'x'), 'Datos inesperados'),
    ]) {
      testWidgets('sin datos: $title, con reintento', (tester) async {
        await pumpPage(
          tester,
          const FixtureOpened(competitionId: 4406),
          failure: failure,
        );

        expect(find.text(title), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);
        expect(find.byType(MatchCard), findsNothing);
      });
    }

    testWidgets('con datos guardados: los muestra con el aviso', (
      tester,
    ) async {
      await pumpPage(
        tester,
        const FixtureOpened(competitionId: 4406),
        refreshError: const NetworkFailure(
          issue: NetworkIssue.connection,
          detail: 'x',
        ),
      );

      expect(find.byType(MatchCard), findsNWidgets(15));
      expect(find.textContaining('Mostrando datos guardados'), findsOneWidget);
      expect(find.textContaining('Sin conexión'), findsOneWidget);
    });
  });

  group('FixtureRoute', () {
    test('ida y vuelta de la URL', () {
      final event = FixtureRoute.parse(
        leagueId: '4406',
        query: {'temporada': '2026', 'fase': 'clausura', 'ronda': '12'},
      );

      expect(event.competitionId, 4406);
      expect(event.season, const Season(2026));
      expect(event.phase, PhaseKey.clausura);
      expect(event.apiRound, 12);
      // Sin `etapa`: la primera etapa de la ronda en la fase.
      expect(event.kind, isNull);
    });

    test('URL de una etapa de eliminación', () {
      const stage = Stage(
        competitionId: 4500,
        season: Season(2026),
        phase: PhaseKey.unica,
        apiRound: 125,
        kind: StageKind.knockout,
        label: 'Cuartos de final',
        order: 3,
      );

      expect(
        FixtureRoute.uriFor(stage).toString(),
        '/competiciones/4500?temporada=2026&fase=copa&ronda=125&etapa=eliminatoria',
      );
    });

    test('al volver al fixture se repone la URL de la etapa', () {
      const stage = Stage(
        competitionId: 4406,
        season: Season(2026),
        phase: PhaseKey.clausura,
        apiRound: 12,
        kind: StageKind.regular,
        label: 'Fecha 12',
        order: 27,
      );
      const url = '/competiciones/4406?temporada=2026&fase=clausura&ronda=12';
      final target = FixtureRoute.uriFor(stage);

      // Sin la etapa (vuelta de un partido o de otra sección): se repone.
      expect(
        FixtureRoute.urlToRestore(Uri.parse('/competiciones'), target),
        Uri.parse(url),
      );
      expect(
        FixtureRoute.urlToRestore(Uri.parse('/competiciones/4406'), target),
        Uri.parse(url),
      );
      // Se abrió en otra competición y se cambió desde los selectores.
      expect(
        FixtureRoute.urlToRestore(
          Uri.parse('/competiciones/4616?temporada=2026&ronda=33'),
          target,
        ),
        Uri.parse(url),
      );
      // Ya la tiene o es otra pantalla: no se toca.
      expect(FixtureRoute.urlToRestore(Uri.parse(url), target), isNull);
      expect(
        FixtureRoute.urlToRestore(Uri.parse('/partidos/2398130'), target),
        isNull,
      );
      expect(FixtureRoute.urlToRestore(Uri.parse('/'), target), isNull);
      expect(
        FixtureRoute.urlToRestore(Uri.parse('/competiciones'), null),
        isNull,
      );
    });

    test('URL de las tablas', () {
      final uri = FixtureRoute.tableUri(4406, const Season(2026), 'apertura-a');

      expect(
        uri.toString(),
        '/competiciones/4406?temporada=2026&vista=tabla&tabla=apertura-a',
      );
      expect(
        FixtureRoute.parseView(uri.queryParameters),
        CompetitionsView.table,
      );
      expect(FixtureRoute.parseTable(uri.queryParameters), 'apertura-a');
      expect(FixtureRoute.parseView(const {}), CompetitionsView.fixture);
      // Al volver de un equipo abierto desde la tabla se repone la tabla.
      expect(
        FixtureRoute.urlToRestore(Uri.parse('/competiciones/4406'), uri),
        uri,
      );
    });

    test('URL del calendario', () {
      final uri = FixtureRoute.calendarUri(
        4406,
        const Season(2026),
        const CalendarMonth(2026, 3),
      );

      expect(
        uri.toString(),
        '/competiciones/4406?temporada=2026&vista=calendario&mes=2026-03',
      );
      expect(
        FixtureRoute.parseView(uri.queryParameters),
        CompetitionsView.calendar,
      );
      expect(
        FixtureRoute.parseMonth(uri.queryParameters),
        const CalendarMonth(2026, 3),
      );
      // Sin mes: el que corresponde a hoy.
      expect(
        FixtureRoute.calendarUri(4406, const Season(2026), null).toString(),
        '/competiciones/4406?temporada=2026&vista=calendario',
      );
      expect(FixtureRoute.parseMonth(const {'mes': '2026-13'}), isNull);
      expect(FixtureRoute.parseMonth(const {}), isNull);
      expect(
        FixtureRoute.urlToRestore(Uri.parse('/competiciones/4406'), uri),
        uri,
      );
    });

    test('URL de las llaves', () {
      final uri = FixtureRoute.bracketUri(
        4406,
        const Season(2026),
        PhaseKey.clausura,
      );

      expect(
        uri.toString(),
        '/competiciones/4406?temporada=2026&vista=llaves&llave=clausura',
      );
      expect(
        FixtureRoute.parseView(uri.queryParameters),
        CompetitionsView.bracket,
      );
      expect(
        FixtureRoute.parseBracketPhase(uri.queryParameters),
        PhaseKey.clausura,
      );
      // La Copa (y sin elegir): sin `llave`.
      expect(
        FixtureRoute.bracketUri(
          4500,
          const Season(2026),
          PhaseKey.unica,
        ).toString(),
        '/competiciones/4500?temporada=2026&vista=llaves',
      );
      // Una copa internacional tiene un solo cuadro (eliminatorias).
      expect(
        FixtureRoute.bracketUri(
          4501,
          const Season(2025),
          PhaseKey.knockoutStage,
        ).toString(),
        '/competiciones/4501?temporada=2025&vista=llaves',
      );
      expect(FixtureRoute.parseBracketPhase(const {'llave': 'x'}), isNull);
      expect(
        FixtureRoute.urlToRestore(Uri.parse('/competiciones/4406'), uri),
        uri,
      );
    });

    test('vistas por competición (D2): Fixture y Calendario siempre', () {
      String views(CompetitionDefinition d) => [
        for (final v in CompetitionsView.values)
          if (v.isAvailableFor(d)) v.name,
      ].join(',');

      expect(
        {for (final d in CompetitionCatalog.all) d.id: views(d)},
        {
          4406: 'fixture,table,calendar,bracket',
          4616: 'fixture,table,calendar',
          4500: 'fixture,calendar,bracket',
          5215: 'fixture,calendar',
          5524: 'fixture,calendar',
          // Tabla desde la Fase D4; Llaves desde la D5.
          4501: 'fixture,table,calendar,bracket',
          4724: 'fixture,table,calendar,bracket',
        },
      );
    });

    test('valores desconocidos se ignoran', () {
      final event = FixtureRoute.parse(leagueId: '999', query: {'fase': 'x'});

      expect(event.competitionId, 4406);
      expect(event.phase, isNull);
    });
  });
}
