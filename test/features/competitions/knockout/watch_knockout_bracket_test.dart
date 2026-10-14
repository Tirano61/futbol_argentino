import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/sync/cancel_token.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/phase.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/usecases/watch_knockout_bracket.dart';
import 'package:futbol_argentino/features/competitions/presentation/bloc/bracket_bloc.dart';
import 'package:sembast/sembast_memory.dart';

import '../../../helpers/fake_clock.dart';
import '../../../helpers/recorded_api.dart';

class _ClockOf implements Clock {
  _ClockOf(this._clock);

  final FakeClock _clock;

  @override
  DateTime now() => _clock.now();
}

/// `WatchKnockoutBracket` y `BracketBloc` con repositorios reales y
/// respuestas grabadas (domingo 11/10/2026).
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

  Future<BracketView> watch(int competitionId, {int year = 2026}) =>
      WatchKnockoutBracket(api.matches)(
        competitionId,
        Season(year),
        now: clock.now(),
        cancelToken: CancelToken(),
      ).last;

  List<String> rounds() => [
    for (final u in api.requests)
      '${u.queryParameters['id']}:r${u.queryParameters['r']}',
  ];

  test('Primera en frío: la ronda 16 y la 0 (2 peticiones); en caliente, '
      '0', () async {
    final view = await watch(4406);
    expect(rounds(), ['4406:r16', '4406:r0']);
    expect(view.brackets.keys, [PhaseKey.apertura]);
    expect(
      view
          .brackets[PhaseKey.apertura]!
          .rounds
          .last
          .slots
          .single
          .outcome!
          .winner
          .name,
      'Belgrano',
    );
    expect(view.progress.isRunning, isFalse);
    expect(view.progress.fetched, 2);

    final hot = await watch(4406);
    expect(api.requests, hasLength(2));
    expect(hot.progress.fetched, 0);
    expect(hot.brackets, view.brackets);
  });

  test(
    'Copa en frío: sus 6 rondas, una vez cada una; en caliente, 0',
    () async {
      final view = await watch(4500);
      expect(rounds(), [
        '4500:r64',
        '4500:r32',
        '4500:r16',
        '4500:r125',
        '4500:r150',
        '4500:r200',
      ]);
      expect(view.brackets[PhaseKey.unica]!.rounds[4].slots, hasLength(2));

      await watch(4500);
      expect(api.requests, hasLength(6));
    },
  );

  test('Nacional: sin cuadro verificado y sin peticiones', () async {
    final view = await watch(4616);
    expect(view.isAvailable, isFalse);
    expect(api.requests, isEmpty);
  });

  BracketBloc build() => BracketBloc(
    watchBracket: WatchKnockoutBracket(api.matches),
    clock: _ClockOf(clock),
  );

  blocTest<BracketBloc, BracketState>(
    'Nacional: sin cuadro',
    build: build,
    act: (bloc) => bloc.add(
      const BracketStarted(competitionId: 4616, season: Season(2026)),
    ),
    expect: () => [const BracketLoading(), isA<BracketUnavailable>()],
  );

  test('carga el cuadro y termina sin descarga en curso', () async {
    final bloc = build()
      ..add(const BracketStarted(competitionId: 4406, season: Season(2026)));
    final done = await bloc.stream.firstWhere(
      (s) => s is BracketLoaded && !s.isBusy,
    );
    expect((done as BracketLoaded).view.brackets, hasLength(1));
    await bloc.close();
  });

  test('Primera 2025 (la API no tiene sus eliminatorias): cargado y sin '
      'cuadros, no un error', () async {
    final bloc = build()
      ..add(const BracketStarted(competitionId: 4406, season: Season(2025)));
    final done = await bloc.stream.firstWhere((s) => !s.isBusy);
    expect(done, isA<BracketLoaded>());
    expect((done as BracketLoaded).view.brackets, isEmpty);
    await bloc.close();
  });

  test('sin red y sin nada guardado: error', () async {
    api.offline = true;
    final bloc = build()
      ..add(const BracketStarted(competitionId: 4406, season: Season(2026)));
    final done = await bloc.stream.firstWhere((s) => !s.isBusy);
    expect(done, isA<BracketFailure>());
    await bloc.close();
  });

  test('pausar detiene la descarga y retomar sigue con lo que falta', () async {
    final bloc = build()
      ..add(const BracketStarted(competitionId: 4500, season: Season(2026)));
    await bloc.stream.firstWhere(
      (s) => s is BracketLoaded && s.view.progress.done >= 1,
    );
    bloc.add(const BracketPaused());
    await pumpEventQueue();
    final paused = api.requests.length;
    expect(paused, lessThan(6));

    bloc.add(const BracketResumed());
    final done = await bloc.stream.firstWhere(
      (s) => s is BracketLoaded && !s.isBusy,
    );
    expect((done as BracketLoaded).view.progress.done, 6);
    expect(api.requests, hasLength(6));
    await bloc.close();
  });
}
