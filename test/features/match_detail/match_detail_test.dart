import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/phase.dart';
import 'package:futbol_argentino/features/match_detail/domain/usecases/get_match_detail.dart';
import 'package:futbol_argentino/features/match_detail/presentation/bloc/match_detail_bloc.dart';
import 'package:futbol_argentino/features/match_detail/presentation/pages/match_detail_page.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
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

    test('competición fuera del catálogo: sin fase', () async {
      final base = fixtureMatches('eventsround_4406_r12_s2026').first;
      final other = Match(
        id: 1,
        competitionId: 4724,
        competitionName: 'CONMEBOL Copa Sudamericana',
        season: '2026',
        apiRound: 150,
        home: base.home,
        away: base.away,
        kickoff: base.kickoff,
        status: base.status,
        lastSeenAt: base.lastSeenAt,
      );

      final detail = (await GetMatchDetail(
        FakeMatchRepository({
          150: [other],
        }),
      )(1)).data;

      expect(detail.competitionName, 'CONMEBOL Copa Sudamericana');
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
    Future<void> pumpPage(WidgetTester tester, int id) async {
      tester.view
        ..physicalSize = const Size(800, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<MatchRepository>.value(value: realRepository()),
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
  });
}
