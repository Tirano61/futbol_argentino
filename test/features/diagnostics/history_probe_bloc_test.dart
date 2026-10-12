import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season.dart';
import 'package:futbol_argentino/features/competitions/domain/entities/season_completion.dart';
import 'package:futbol_argentino/features/competitions/domain/usecases/complete_rounds.dart';
import 'package:futbol_argentino/features/diagnostics/presentation/bloc/history_probe_bloc.dart';
import 'package:sembast/sembast_memory.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/recorded_api.dart';

/// Sección «Historial» de /diagnostico con repositorios reales y
/// respuestas grabadas.
void main() {
  late FakeClock clock;
  late RecordedApi api;
  late HistoryProbeBloc bloc;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 10, 11, 20, 35));
    api = RecordedApi(
      clock: clock,
      db: await newDatabaseFactoryMemory().openDatabase('app.db'),
    );
    bloc = HistoryProbeBloc(
      completeRounds: CompleteRounds(api.matches),
      matches: api.matches,
      clock: clock,
    );
  });

  tearDown(() => bloc.close());

  test('completa la Copa 2026 y actualiza las temporadas guardadas', () async {
    bloc.add(
      const HistoryProbeStarted(competitionId: 4500, season: Season(2026)),
    );
    final done = await bloc.stream.firstWhere(
      (s) => !s.running && s.summaries.isNotEmpty,
    );

    expect(api.requests, hasLength(6));
    expect(done.cancelled, isFalse);
    expect(done.completion!.progress.done, 6);
    expect(done.completion!.rounds.map((r) => r.status).toSet(), {
      RoundCompletionStatus.fetched,
    });
    expect(done.summaries.single.matchCount, 62);
  });

  test('cancelar detiene la carga en curso', () async {
    bloc.add(
      const HistoryProbeStarted(competitionId: 4616, season: Season(2026)),
    );
    await bloc.stream.firstWhere(
      (s) => (s.completion?.progress.done ?? 0) >= 2,
    );
    bloc.add(const HistoryProbeCancelled());
    final stopped = await bloc.stream.firstWhere((s) => !s.running);
    final atCancel = api.requests.length;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(stopped.cancelled, isTrue);
    expect(api.requests.length, atCancel);
    expect(api.requests.length, lessThan(36));
    expect(api.scheduler.pending, 0);
  });
}
