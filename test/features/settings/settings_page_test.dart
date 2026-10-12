import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:futbol_argentino/features/favorites/domain/entities/favorite_team.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:futbol_argentino/features/settings/domain/usecases/stored_seasons.dart';
import 'package:futbol_argentino/features/settings/presentation/bloc/stored_data_bloc.dart';
import 'package:futbol_argentino/features/settings/presentation/pages/settings_page.dart';
import 'package:sembast/sembast_memory.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/fakes.dart';
import '../../helpers/favorites.dart';
import '../../helpers/recorded_api.dart';

final now = DateTime.utc(2026, 10, 12, 15);

/// Base con rondas reales guardadas: Primera 2026 y 2025 (fecha 1) y Copa
/// 2025 (16avos), y Boca como favorito.
Future<({RecordedApi api, FavoritesRepositoryImpl favorites})>
storedData() async {
  final db = await newDatabaseFactoryMemory().openDatabase('app.db');
  final api = RecordedApi(clock: FakeClock(now), db: db);
  for (final q in const [
    RoundQuery(competitionId: 4406, season: '2026', apiRound: 1),
    RoundQuery(competitionId: 4406, season: '2025', apiRound: 1),
    RoundQuery(competitionId: 4500, season: '2025', apiRound: 32),
  ]) {
    await api.matches.syncRound(q);
  }
  final favorites = FavoritesRepositoryImpl(db);
  await favorites.save(
    FavoriteTeam(teamId: 135156, name: 'Boca Juniors', addedAt: now),
  );
  return (api: api, favorites: favorites);
}

void main() {
  group('StoredDataBloc', () {
    late RecordedApi api;

    setUp(() async => api = (await storedData()).api);

    StoredDataBloc build() => StoredDataBloc(
      getStoredSeasons: GetStoredSeasons(api.matches),
      deleteStoredSeasons: DeleteStoredSeasons(api.matches),
      clock: FixedClock(now),
    );

    blocTest<StoredDataBloc, StoredDataState>(
      'marca solo temporadas que se pueden borrar',
      build: build,
      act: (bloc) async {
        bloc.add(const StoredDataStarted());
        await bloc.stream.firstWhere((s) => s is StoredDataLoaded);
        bloc
          ..add(const StoredDataToggled('4406:2026'))
          ..add(const StoredDataToggled('4406:2025'))
          ..add(const StoredDataToggled('4500:2025'))
          ..add(const StoredDataToggled('4500:2025'));
      },
      skip: 1,
      expect: () => [
        isA<StoredDataLoaded>().having((s) => s.selected, 'selected', {
          '4406:2025',
        }),
        isA<StoredDataLoaded>().having((s) => s.selected, 'selected', {
          '4406:2025',
          '4500:2025',
        }),
        isA<StoredDataLoaded>().having((s) => s.selected, 'selected', {
          '4406:2025',
        }),
      ],
    );

    blocTest<StoredDataBloc, StoredDataState>(
      'borra lo marcado y vuelve a leer',
      build: build,
      act: (bloc) async {
        bloc.add(const StoredDataStarted());
        await bloc.stream.firstWhere((s) => s is StoredDataLoaded);
        bloc
          ..add(const StoredDataToggled('4406:2025'))
          ..add(const StoredDataDeleteRequested());
        await bloc.stream.firstWhere(
          (s) => s is StoredDataLoaded && s.lastDeleted != null,
        );
      },
      skip: 2,
      expect: () => [
        isA<StoredDataLoaded>().having((s) => s.isDeleting, 'borrando', true),
        isA<StoredDataLoaded>()
            .having((s) => s.lastDeleted, 'borrados', 30)
            .having((s) => s.selected, 'selected', isEmpty)
            .having((s) => s.seasons.map((x) => x.key), 'temporadas', [
              '4406:2026',
              '4500:2025',
            ]),
      ],
    );
  });

  testWidgets('Datos guardados: elegir, confirmar y borrar', (tester) async {
    final data = await outsideFakeAsync(tester, storedData);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<MatchRepository>.value(value: data.api.matches),
          RepositoryProvider<Clock>.value(value: FixedClock(now)),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Datos guardados'), findsOne);
    expect(find.text('Primera División'), findsOne);
    expect(find.text('Copa Argentina'), findsOne);
    expect(
      find.text('30 partidos · temporada actual, no se puede borrar'),
      findsOne,
    );
    expect(find.byType(Checkbox), findsNWidgets(2));
    FilledButton deleteButton() => tester.widget<FilledButton>(
      find.ancestor(
        of: find.textContaining('Borrar seleccionadas'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(deleteButton().onPressed, isNull);

    // La temporada actual no se marca.
    await tester.tap(find.text('Temporada 2026'));
    await tester.pumpAndSettle();
    expect(deleteButton().onPressed, isNull);

    await tester.tap(find.text('Temporada 2025').first);
    await tester.pumpAndSettle();
    expect(find.text('Borrar seleccionadas (1)'), findsOne);

    // Cancelar no borra nada.
    await tester.tap(find.text('Borrar seleccionadas (1)'));
    await tester.pumpAndSettle();
    expect(find.text('• Primera División 2025: 30 partidos'), findsOne);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Temporada 2025'), findsNWidgets(2));

    await tester.tap(find.text('Borrar seleccionadas (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pumpAndSettle();

    expect(find.text('Se borraron 30 partidos.'), findsOne);
    // Queda solo la Copa 2025.
    expect(find.text('Temporada 2025'), findsOne);
    expect(find.text('16 partidos'), findsOne);
    final left = await outsideFakeAsync(tester, () async {
      return (
        primera2025: await data.api.matches.storedSeason(4406, '2025'),
        primera2026: await data.api.matches.storedSeason(4406, '2026'),
        boca: await data.favorites.contains(135156),
      );
    });
    expect(left.primera2025, isEmpty);
    expect(left.primera2026, hasLength(30));
    expect(left.boca, isTrue);
  });
}
