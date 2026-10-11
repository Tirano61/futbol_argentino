import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/features/competitions/domain/catalog/competition_catalog.dart';
import 'package:futbol_argentino/features/home/domain/usecases/get_home_feed.dart';
import 'package:futbol_argentino/features/home/presentation/bloc/home_bloc.dart';

import '../../helpers/fakes.dart';
import '../../helpers/recorded_home.dart';

void main() {
  final now = DateTime.utc(2026, 10, 11, 20);
  const offline = NetworkFailure(
    issue: NetworkIssue.connection,
    detail: 'Failed host lookup',
  );

  late FakeMatchRepository matches;
  late FakeCompetitionRepository competitions;

  HomeBloc build() => HomeBloc(
    getHomeFeed: GetHomeFeed(competitions: competitions, matches: matches),
    clock: FixedClock(now),
  );

  setUp(() {
    matches = FakeMatchRepository(recordedRounds());
    competitions = FakeCompetitionRepository(
      pointersById: {
        for (final d in CompetitionCatalog.all) d.id: recordedPointers(d.id),
      },
    );
  });

  test('estado inicial', () {
    expect(build().state, const HomeInitial());
  });

  test('carga: «cargando» y después datos que se completan', () async {
    final bloc = build();
    final states = <HomeState>[];
    final subscription = bloc.stream.listen(states.add);
    bloc.add(const HomeStarted());
    await bloc.stream.firstWhere((s) => s is HomeLoaded && !s.isBusy);
    await subscription.cancel();

    expect(states.first, const HomeLoading());
    expect(states.skip(1), everyElement(isA<HomeLoaded>()));
    expect(states[1].isBusy, isTrue);
    final last = states.last as HomeLoaded;
    expect(last.feed.todayMatches, hasLength(17));
    expect(last.feed.upcoming, hasLength(37));
    expect(last.feed.recent, hasLength(8));
    await bloc.close();
  });

  blocTest<HomeBloc, HomeState>(
    'sin red y sin nada guardado: error',
    setUp: () => competitions = FakeCompetitionRepository(failure: offline),
    build: build,
    act: (bloc) => bloc.add(const HomeStarted()),
    expect: () => [const HomeLoading(), const HomeFailure(offline)],
  );

  test(
    'refresco manual: nunca vuelve a «cargando» ni vacía la lista',
    () async {
      final bloc = build()..add(const HomeStarted());
      await bloc.stream.firstWhere((s) => s is HomeLoaded && !s.isBusy);
      // Que termine el handler anterior (si no, `droppable` lo descarta).
      await Future<void>.delayed(Duration.zero);

      final states = <HomeState>[];
      final subscription = bloc.stream.listen(states.add);
      bloc.add(const HomeRefreshRequested());
      await bloc.stream.firstWhere((s) => !s.isBusy);
      await subscription.cancel();

      expect(states.first.isBusy, isTrue);
      for (final s in states) {
        expect(s, isA<HomeLoaded>());
        expect((s as HomeLoaded).feed.todayMatches, hasLength(17));
      }
      expect(competitions.pointerCalls.where((c) => c.force), hasLength(3));
      await bloc.close();
    },
  );

  test('droppable: un pedido durante la carga se descarta', () async {
    final bloc = build()
      ..add(const HomeStarted())
      ..add(const HomeRefreshRequested());
    await bloc.stream.firstWhere((s) => s is HomeLoaded && !s.isBusy);
    await Future<void>.delayed(Duration.zero);

    expect(competitions.pointerCalls, hasLength(3));
    expect(competitions.pointerCalls.every((c) => !c.force), isTrue);
    await bloc.close();
  });
}
