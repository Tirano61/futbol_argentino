import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/phase.dart';
import 'package:futbol_argentino/features/match_detail/domain/usecases/get_match_detail.dart';
import 'package:futbol_argentino/features/match_detail/presentation/bloc/match_detail_bloc.dart';
import 'package:futbol_argentino/features/match_detail/presentation/formatters/match_detail_texts.dart';
import 'package:futbol_argentino/features/match_detail/presentation/pages/match_detail_page.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:futbol_argentino/features/matches/domain/services/tie_outcome.dart';
import 'package:futbol_argentino/shared/presentation/formatters/match_labels.dart';

import '../../helpers/fakes.dart';
import '../../helpers/fixture_matches.dart';

FakeMatchRepository realRepository() => FakeMatchRepository({
  12: fixtureMatches('eventsround_4406_r12_s2026'),
  16: fixtureMatches('eventsround_4406_r16_s2026'),
  34: fixtureMatches('eventsround_4616_r34_s2026'),
  125: fixtureMatches('eventsround_4500_r125_s2026'),
});

void main() {
  group('GetMatchDetail', () {
    final getDetail = GetMatchDetail(realRepository());

    test('Primera: competición, fase y fecha', () async {
      // Gimnasia y Esgrima de Mendoza – Newell's (Clausura, fecha 12).
      final detail = (await getDetail(2398120)).data;

      expect(detail.competitionName, 'Primera División');
      expect(detail.phase!.phase, PhaseKey.clausura);
      expect(detail.stageLabel, 'Fecha 12');
    });

    test('octavos del Apertura en la ronda 16', () async {
      final octavo = fixtureMatches(
        'eventsround_4406_r16_s2026',
      ).firstWhere((m) => m.kickoff.argentinaDay!.month == 5);

      final detail = (await getDetail(octavo.id)).data;

      expect(detail.phase!.stageKind, StageKind.knockout);
      expect(detail.stageLabel, 'Octavos de final');
    });

    test('Copa: cuartos de final', () async {
      final cuartos = fixtureMatches('eventsround_4500_r125_s2026').first;

      final detail = (await getDetail(cuartos.id)).data;

      expect(detail.competitionName, 'Copa Argentina');
      expect(detail.stageLabel, 'Cuartos de final');
    });

    test('Fase D3: copas internacionales, con fase y etapa', () async {
      final r1 = fixtureMatches('eventsround_4501_r1_s2026');
      final r16 = fixtureMatches('eventsround_4501_r16_s2026');
      final getCup = GetMatchDetail(FakeMatchRepository({1: r1, 16: r16}));
      Future<String> line(int id) async =>
          MatchDetailTexts.competitionLine((await getCup(id)).data);

      // La ronda 1 de 2026 trae la Fase 1 (febrero) y la Fecha 1 (abril).
      final february = r1.firstWhere((m) => m.kickoff.argentinaDay!.month == 2);
      final april = r1.firstWhere((m) => m.kickoff.argentinaDay!.month == 4);
      expect(
        await line(february.id),
        'Copa Libertadores · Fases previas · Fase 1',
      );
      expect(
        await line(april.id),
        'Copa Libertadores · Fase de grupos · Fecha 1',
      );
      expect(
        await line(r16.first.id),
        'Copa Libertadores · Eliminatorias · Octavos de final',
      );

      // Una pierna empatada dice quién avanzó en la serie (Fase D5).
      final drawn = r16.firstWhere(
        (m) =>
            m.status.isFinished &&
            m.penalties == null &&
            m.score!.home == m.score!.away,
      );
      final detail = (await getCup(drawn.id)).data;
      expect(detail.tie!.legs, hasLength(2));
      expect(detail.advancement, isNotNull);
    });

    group('Fase D5: series de las copas internacionales', () {
      GetMatchDetail detailOf(int league, int year, List<int> rounds) =>
          GetMatchDetail(
            FakeMatchRepository({
              for (final r in rounds)
                r: fixtureMatches('eventsround_${league}_r${r}_s$year'),
            }),
          );

      Match leg(int league, int year, int round, String home) => fixtureMatches(
        'eventsround_${league}_r${round}_s$year',
      ).singleWhere((m) => m.home.name == home);

      test(
        'la ida y la vuelta muestran la misma serie, con el global',
        () async {
          final get = detailOf(4501, 2025, [16, 125]);
          final ida = leg(4501, 2025, 16, 'Peñarol');
          final vuelta = leg(4501, 2025, 16, 'Racing Club');
          final first = (await get(ida.id)).data;
          final second = (await get(vuelta.id)).data;
          expect(first.tie, second.tie);
          expect(first.tie!.legs.map((m) => m.id), [ida.id, vuelta.id]);
          expect(
            MatchLabels.aggregate(first.tie!),
            'Global Peñarol 2-3 Racing Club',
          );
          // La ida la ganó Peñarol, pero la serie es de Racing.
          expect(first.advancement!.source, TieOutcomeSource.aggregate);
          expect(
            MatchLabels.tieAdvances(first.advancement!, first.tie!),
            'Clasificó Racing Club por resultado global (3-2)',
          );
        },
      );

      test('2025 sin penales: el que juega después, con lo guardado de la '
          'temporada', () async {
        final river = leg(4501, 2025, 16, 'River Plate');
        final without = (await detailOf(4501, 2025, [16])(river.id)).data;
        expect(without.tie!.isComplete, isTrue);
        expect(without.advancement, isNull);

        final withLater = (await detailOf(4501, 2025, [16, 125])(
          river.id,
        )).data;
        expect(withLater.advancement!.source, TieOutcomeSource.laterMatch);
        expect(withLater.advancement!.winner.name, 'River Plate');
      });

      test('vuelta ganada con el global empatado: la tanda (LDU 3-2 '
          'Palmeiras, 3-4 en penales)', () async {
        final vuelta = leg(4501, 2026, 125, 'LDU Quito');
        final detail = (await detailOf(4501, 2026, [125])(vuelta.id)).data;
        expect(detail.advancement!.source, TieOutcomeSource.penalties);
        expect(
          MatchLabels.tieAdvances(detail.advancement!, detail.tie!),
          'Clasificó Palmeiras por penales (4-3)',
        );
      });

      test('Sudamericana: PEN sin tanda → la semifinal guardada', () async {
        final vuelta = leg(4724, 2026, 125, 'Atlético Mineiro');
        final detail = (await detailOf(4724, 2026, [125, 150])(vuelta.id)).data;
        expect(detail.advancement!.source, TieOutcomeSource.laterMatch);
        expect(detail.advancement!.winner.name, 'Atlético Mineiro');
      });

      test('Sudamericana 2026: Primera fase a un partido (PEN sin tanda) → '
          'el que juega los grupos', () async {
        final r1 = fixtureMatches('eventsround_4724_r1_s2026');
        final petrolero = r1.singleWhere(
          (m) =>
              m.home.name == 'Independiente Petrolero' &&
              m.kickoff.argentinaDay!.month == 3,
        );
        final detail = (await detailOf(4724, 2026, [1])(petrolero.id)).data;
        expect(detail.tie!.isSeries, isFalse);
        expect(detail.advancement!.source, TieOutcomeSource.laterMatch);
        expect(detail.advancement!.winner.name, 'Independiente Petrolero');
      });

      test('final de la Sudamericana 2025: completa y sin dato de quién '
          'ganó', () async {
        final finalMatch = fixtureMatches('eventsround_4724_r200_s2025').single;
        final detail = (await detailOf(4724, 2025, [150, 200])(
          finalMatch.id,
        )).data;
        expect(detail.tie!.isComplete, isTrue);
        expect(detail.advancement, isNull);
      });

      test('los grupos no son llaves', () async {
        final group = fixtureMatches('eventsround_4501_r4_s2026').first;
        final detail = (await detailOf(4501, 2026, [4])(group.id)).data;
        expect(detail.tie, isNull);
        expect(detail.advancement, isNull);
      });
    });

    test('competición fuera del catálogo: sin fase', () async {
      // Torneo Federal A (5523): fuera del catálogo (V8).
      final other = fixtureMatches('eventsround_5523_r1_s2026').first;

      final detail = (await GetMatchDetail(
        FakeMatchRepository({
          1: [other],
        }),
      )(other.id)).data;

      expect(detail.competitionName, 'Argentina Torneo Federal A');
      expect(detail.phase, isNull);
      expect(detail.stageLabel, isNull);
    });
  });

  group('MatchDetailBloc', () {
    blocTest<MatchDetailBloc, MatchDetailState>(
      'carga el partido',
      build: () => MatchDetailBloc(GetMatchDetail(realRepository())),
      act: (bloc) => bloc.add(const MatchDetailStarted(2398120)),
      expect: () => [
        isA<MatchDetailLoading>(),
        isA<MatchDetailLoaded>().having(
          (s) => s.result.data.match.id,
          'id',
          2398120,
        ),
      ],
    );

    blocTest<MatchDetailBloc, MatchDetailState>(
      'sin datos y sin conexión: error',
      build: () => MatchDetailBloc(GetMatchDetail(FakeMatchRepository({}))),
      act: (bloc) => bloc.add(const MatchDetailStarted(1)),
      expect: () => [
        isA<MatchDetailLoading>(),
        isA<MatchDetailFailure>().having(
          (s) => s.failure,
          'failure',
          isA<NotFoundFailure>(),
        ),
      ],
    );

    test('refresco que falla: conserva los datos con el error', () async {
      final repo = realRepository();
      final bloc = MatchDetailBloc(GetMatchDetail(repo))
        ..add(const MatchDetailStarted(2398120));
      final loaded =
          await bloc.stream.firstWhere((s) => s is MatchDetailLoaded)
              as MatchDetailLoaded;

      repo.failure = const NetworkFailure(
        issue: NetworkIssue.connection,
        detail: 'offline',
      );
      bloc.add(const MatchDetailRefreshRequested());
      final refreshed =
          await bloc.stream.firstWhere(
                (s) => s is MatchDetailLoaded && s.result.refreshError != null,
              )
              as MatchDetailLoaded;

      expect(refreshed.result.data, loaded.result.data);
      expect(refreshed.result.refreshError, isA<NetworkFailure>());
      expect(refreshed.isRefreshing, isFalse);
      await bloc.close();
    });
  });

  group('MatchDetailPage', () {
    Future<void> pumpPage(
      WidgetTester tester,
      int id, {
      FakeMatchRepository? repository,
    }) async {
      tester.view
        ..physicalSize = const Size(800, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<MatchRepository>.value(
              value: repository ?? realRepository(),
            ),
            RepositoryProvider<Clock>.value(
              value: FixedClock(DateTime.utc(2026, 10, 11, 21)),
            ),
          ],
          child: MaterialApp(home: MatchDetailPage(matchId: id)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('partido real con estadio, video y horario sin confirmar', (
      tester,
    ) async {
      // Atlético Tucumán 1 – 0 Gimnasia LP, 2026-03-21T00:00:00 (local 18:00).
      await pumpPage(tester, 2397877);

      expect(find.text('Primera División'), findsOneWidget);
      expect(find.text('Apertura · Fecha 12'), findsOneWidget);
      expect(find.text('1 – 0'), findsOneWidget);
      expect(find.text('Sábado 21/03/2026'), findsOneWidget);
      expect(find.text(MatchLabels.unconfirmedTime), findsOneWidget);
      expect(find.textContaining('sin confirmar'), findsOneWidget);
      expect(
        find.text('Estadio Monumental Presidente José Fierro'),
        findsOneWidget,
      );
      expect(find.text('Ver video'), findsOneWidget);
      expect(find.text('Final'), findsWidgets);
    });

    testWidgets('campos ausentes no se muestran', (tester) async {
      final noExtras = fixtureMatches(
        'eventsround_4616_r34_s2026',
      ).firstWhere((m) => m.videoUrl == null);

      await pumpPage(tester, noExtras.id);

      expect(find.text('Ver video'), findsNothing);
      expect(find.text('null'), findsNothing);
      // Programado y no vencido: sin fila de estado.
      expect(find.text('Estado'), findsNothing);
      expect(find.text('Primera Nacional'), findsOneWidget);
      expect(find.text('Fecha 34'), findsOneWidget);
    });

    testWidgets('sin datos ni red: pantalla de error con reintento', (
      tester,
    ) async {
      await pumpPage(
        tester,
        2397877,
        repository: realRepository()
          ..failure = const NetworkFailure(
            issue: NetworkIssue.timeout,
            detail: 'x',
          ),
      );

      expect(find.text('La consulta tardó demasiado'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('con datos guardados: los muestra con el aviso', (
      tester,
    ) async {
      await pumpPage(
        tester,
        2397877,
        repository: FakeMatchRepository({
          12: fixtureMatches('eventsround_4406_r12_s2026'),
        }, refreshError: const RateLimitFailure(detail: '429')),
      );

      expect(find.text('1 – 0'), findsOneWidget);
      expect(find.textContaining('Mostrando datos guardados'), findsOneWidget);
      expect(find.textContaining('Demasiadas consultas'), findsOneWidget);
    });
  });
}
