import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/sync/sync_scheduler.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/usecases/watch_competition_calendar.dart';
import 'package:futbol_argentino/features/competitions/presentation/bloc/calendar_bloc.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:sembast/sembast_memory.dart';

import '../../../helpers/fake_clock.dart';
import '../../../helpers/recorded_api.dart';

class _ClockOf implements Clock {
  _ClockOf(this._clock);

  final FakeClock _clock;

  @override
  DateTime now() => _clock.now();
}

/// `CalendarBloc` con repositorios reales y respuestas grabadas.
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

  CalendarBloc build() => CalendarBloc(
    watchCalendar: WatchCompetitionCalendar(api.matches),
    clock: _ClockOf(clock),
  );

  const primera2026 = CalendarStarted(
    competitionId: 4406,
    season: Season(2026),
  );

  Future<CalendarLoaded> settled(CalendarBloc bloc) async =>
      await bloc.stream.firstWhere((s) => s is CalendarLoaded && !s.isBusy)
          as CalendarLoaded;

  test('abrir: solo lo guardado, sin peticiones', () async {
    await api.matches.syncRound(
      const RoundQuery(competitionId: 4406, season: '2026', apiRound: 12),
      priority: SyncPriority.visible,
    );
    api.requests.clear();
    final bloc = build()..add(primera2026);

    final loaded = await settled(bloc);

    expect(loaded.view.matches, hasLength(30));
    expect(loaded.view.roundsPending, 16);
    expect(api.requests, isEmpty);
    await bloc.close();
  });

  test('«Completar» descarga lo que falta, de a una fecha', () async {
    final bloc = build()..add(primera2026);
    await settled(bloc);

    bloc.add(const CalendarCompletionRequested());
    final states = <CalendarState>[];
    final sub = bloc.stream.listen(states.add);
    final done = await settled(bloc);
    await sub.cancel();

    expect(done.view.matches, hasLength(495));
    expect(done.view.roundsPending, 0);
    expect(api.requests, hasLength(17));
    expect(
      states.first,
      isA<CalendarLoaded>().having(
        (s) => s.isRefreshing,
        'isRefreshing',
        isTrue,
      ),
    );
    expect(
      states.whereType<CalendarLoaded>().where(
        (s) => s.view.progress.isRunning,
      ),
      isNotEmpty,
    );
    await bloc.close();
  });

  test(
    'pausar detiene la descarga; retomar sigue solo con lo que falta',
    () async {
      final bloc = build()..add(primera2026);
      await settled(bloc);
      bloc.add(const CalendarCompletionRequested());
      await bloc.stream.firstWhere(
        (s) => s is CalendarLoaded && s.view.progress.done >= 3,
      );

      bloc.add(const CalendarPaused());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final atPause = api.requests.length;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(api.requests.length, atPause, reason: 'en pausa no pide nada');
      expect(atPause, lessThan(17));

      bloc.add(const CalendarResumed());
      final done = await bloc.stream.firstWhere(
        (s) => s is CalendarLoaded && !s.isBusy && s.view.roundsPending == 0,
      );

      expect((done as CalendarLoaded).view.matches, hasLength(495));
      // Ninguna fecha se pidió dos veces.
      expect(api.requests, hasLength(17));
      expect(api.requestLabels.toSet(), hasLength(17));
      await bloc.close();
    },
  );

  test(
    'retomar sin descarga pendiente vuelve a leer lo guardado (sin red)',
    () async {
      final bloc = build()..add(primera2026);
      final empty = await settled(bloc);
      expect(empty.view.matches, isEmpty);

      // Mientras el calendario no se veía, el fixture guardó la fecha 12.
      bloc.add(const CalendarPaused());
      await api.matches.syncRound(
        const RoundQuery(competitionId: 4406, season: '2026', apiRound: 12),
        priority: SyncPriority.visible,
      );
      api.requests.clear();
      bloc.add(const CalendarResumed());
      final reloaded = await bloc.stream.firstWhere(
        (s) => s is CalendarLoaded && s.view.matches.isNotEmpty,
      );

      expect((reloaded as CalendarLoaded).view.matches, hasLength(30));
      expect(api.requests, isEmpty);
      await bloc.close();
    },
  );

  test('retomar durante una descarga no la corta', () async {
    final bloc = build()..add(primera2026);
    await settled(bloc);
    bloc.add(const CalendarCompletionRequested());
    await bloc.stream.firstWhere(
      (s) => s is CalendarLoaded && s.view.progress.done >= 2,
    );

    bloc.add(const CalendarResumed());
    final done = await settled(bloc);

    expect(done.view.progress.done, 17);
    expect(api.requests, hasLength(17));
    await bloc.close();
  });

  test('actualizar con todo al día termina (sin consultas)', () async {
    final bloc = build()..add(primera2026);
    await settled(bloc);
    bloc.add(const CalendarCompletionRequested());
    final loaded = await bloc.stream.firstWhere(
      (s) => s is CalendarLoaded && !s.isBusy && s.view.roundsPending == 0,
    );
    api.requests.clear();

    // Menos de 30 s después de la descarga: nada que consultar.
    bloc.add(const CalendarRefreshRequested());
    final after = await settled(bloc);

    expect(api.requests, isEmpty);
    expect(after.view.matches, (loaded as CalendarLoaded).view.matches);
    expect(after.view.progress.fetched, 0);
    await bloc.close();
  });

  test('otra competición reemplaza a la anterior', () async {
    final bloc = build()..add(primera2026);
    await settled(bloc);

    bloc.add(const CalendarStarted(competitionId: 4500, season: Season(2026)));

    expect(await bloc.stream.first, isA<CalendarLoading>());
    final copa = await settled(bloc);
    expect(copa.view.competitionId, 4500);
    expect(copa.view.roundsTotal, 6);
    await bloc.close();
  });
}
