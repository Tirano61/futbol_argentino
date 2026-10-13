import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/usecases/watch_standings.dart';
import 'package:futbol_argentino/features/competitions/presentation/bloc/standings_bloc.dart';
import 'package:sembast/sembast_memory.dart';

import '../../../helpers/fake_clock.dart';
import '../../../helpers/recorded_api.dart';

class _ClockOf implements Clock {
  _ClockOf(this._clock);

  final FakeClock _clock;

  @override
  DateTime now() => _clock.now();
}

/// `StandingsBloc` con repositorios reales y respuestas grabadas.
void main() {
  late FakeClock clock;
  late RecordedApi api;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 10, 11, 20, 35));
    api = RecordedApi(
      clock: clock,
      db: await newDatabaseFactoryMemory().openDatabase('app.db'),
    );
  });

  StandingsBloc build() => StandingsBloc(
    watchStandings: WatchStandings(api.matches),
    clock: _ClockOf(clock),
  );

  const primera2026 = StandingsStarted(
    competitionId: 4406,
    season: Season(2026),
  );

  test('carga las tablas y termina sin descarga en curso', () async {
    final bloc = build()..add(primera2026);
    final done = await bloc.stream.firstWhere(
      (s) => s is StandingsLoaded && !s.view.progress.isRunning,
    );

    expect((done as StandingsLoaded).view.tables, hasLength(5));
    expect(api.requests, hasLength(16));
    await bloc.close();
  });

  blocTest<StandingsBloc, StandingsState>(
    'Copa: sin tabla',
    build: build,
    act: (bloc) => bloc.add(
      const StandingsStarted(competitionId: 4500, season: Season(2026)),
    ),
    expect: () => [const StandingsLoading(), isA<StandingsUnavailable>()],
  );

  blocTest<StandingsBloc, StandingsState>(
    'sin red y sin nada guardado: error',
    setUp: () => api.offline = true,
    build: build,
    act: (bloc) => bloc.add(primera2026),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      const StandingsLoading(),
      isA<StandingsFailure>().having(
        (s) => s.failure,
        'failure',
        isA<NetworkFailure>(),
      ),
    ],
  );

  test(
    'pausar detiene la descarga; retomar sigue solo con lo que falta',
    () async {
      final bloc = build()..add(primera2026);
      await bloc.stream.firstWhere(
        (s) => s is StandingsLoaded && s.view.progress.done >= 3,
      );

      bloc.add(const StandingsPaused());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final atPause = api.requests.length;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(api.requests.length, atPause, reason: 'en pausa no pide nada');
      expect(atPause, lessThan(16));

      bloc.add(const StandingsResumed());
      final done = await bloc.stream.firstWhere(
        (s) => s is StandingsLoaded && !s.view.progress.isRunning,
      );

      expect((done as StandingsLoaded).view.tables, hasLength(5));
      // Ninguna fecha se pidió dos veces.
      expect(api.requests, hasLength(16));
      expect(api.requestLabels.toSet(), hasLength(16));
      await bloc.close();
    },
  );

  test('retomar sin haber pausado no corta la carga en curso', () async {
    final bloc = build()..add(primera2026);
    await bloc.stream.firstWhere(
      (s) => s is StandingsLoaded && s.view.progress.done >= 2,
    );

    bloc.add(const StandingsResumed());
    final done = await bloc.stream.firstWhere(
      (s) => s is StandingsLoaded && !s.view.progress.isRunning,
    );

    expect((done as StandingsLoaded).view.progress.done, 16);
    await bloc.close();
  });

  test('actualizar con todo al día termina (sin consultas)', () async {
    final bloc = build()..add(primera2026);
    final loaded = await bloc.stream.firstWhere(
      (s) => s is StandingsLoaded && !s.view.progress.isRunning,
    );
    api.requests.clear();

    // Menos de 30 s después de la descarga: nada que consultar. La emisión
    // final es igual a la anterior; el refresco se marca para que se note.
    bloc.add(const StandingsRefreshRequested());
    final states = await bloc.stream
        .takeWhile((s) => s is! StandingsLoaded || s.isRefreshing)
        .toList()
        .timeout(const Duration(seconds: 5));
    expect(states.single, isA<StandingsLoaded>());
    await Future<void>.delayed(Duration.zero);

    expect(api.requests, isEmpty);
    expect(
      (bloc.state as StandingsLoaded).view.tables,
      (loaded as StandingsLoaded).view.tables,
    );
    expect((bloc.state as StandingsLoaded).view.progress.fetched, 0);

    // Otra vez: ahora la emisión final es idéntica al estado anterior.
    bloc.add(const StandingsRefreshRequested());
    await bloc.stream
        .firstWhere((s) => s is StandingsLoaded && !s.isRefreshing)
        .timeout(const Duration(seconds: 5));
    expect(bloc.state.isBusy, isFalse);
    await bloc.close();
  });

  test('cerrar detiene la descarga', () async {
    final bloc = build()..add(primera2026);
    await bloc.stream.firstWhere(
      (s) => s is StandingsLoaded && s.view.progress.done >= 2,
    );
    final atClose = api.requests.length;

    await bloc.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(api.requests.length, lessThanOrEqualTo(atClose + 1));
    expect(api.requests.length, lessThan(16));
  });
}
