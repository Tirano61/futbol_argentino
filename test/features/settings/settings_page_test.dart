import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/platform/external_actions.dart';
import 'package:futbol_argentino/core/time/clock.dart';
import 'package:futbol_argentino/features/favorites/data/repositories/favorites_repository_impl.dart';
import 'package:futbol_argentino/features/favorites/domain/entities/favorite_team.dart';
import 'package:futbol_argentino/features/matches/domain/repositories/match_repository.dart';
import 'package:futbol_argentino/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:futbol_argentino/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:futbol_argentino/features/settings/domain/usecases/stored_seasons.dart';
import 'package:futbol_argentino/features/settings/presentation/bloc/stored_data_bloc.dart';
import 'package:futbol_argentino/features/settings/presentation/pages/settings_page.dart';
import 'package:sembast/sembast_memory.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/fake_external_actions.dart';
import '../../helpers/fakes.dart';
import '../../helpers/favorites.dart';
import '../../helpers/recorded_api.dart';

final now = DateTime.utc(2026, 10, 12, 15);

/// Base con rondas reales guardadas: Primera 2026 y 2025 (fecha 1) y Copa
/// 2025 (16avos), y Boca como favorito.
Future<
  ({
    RecordedApi api,
    FavoritesRepositoryImpl favorites,
    SettingsRepositoryImpl settings,
  })
>
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
  return (api: api, favorites: favorites, settings: SettingsRepositoryImpl(db));
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
    // Alto suficiente para ver el tema y todas las temporadas.
    tester.view
      ..physicalSize = const Size(800, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final data = await outsideFakeAsync(tester, storedData);
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<MatchRepository>.value(value: data.api.matches),
          RepositoryProvider<Clock>.value(value: FixedClock(now)),
        ],
        child: BlocProvider(
          create: (context) =>
              SettingsBloc(settings: data.settings)
                ..add(const SettingsSubscribed()),
          child: const MaterialApp(home: SettingsPage()),
        ),
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

  group('Fuente', () {
    Future<FakeExternalActions> pumpSettings(
      WidgetTester tester, {
      bool linkOpens = true,
      double textScale = 1,
    }) async {
      tester.view
        ..physicalSize = const Size(360, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      if (textScale != 1) {
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      }
      final data = await outsideFakeAsync(tester, storedData);
      final actions = FakeExternalActions(linkOpens: linkOpens);
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<MatchRepository>.value(value: data.api.matches),
            RepositoryProvider<Clock>.value(value: FixedClock(now)),
            RepositoryProvider<ExternalActions>.value(value: actions),
          ],
          child: BlocProvider(
            create: (context) =>
                SettingsBloc(settings: data.settings)
                  ..add(const SettingsSubscribed()),
            child: const MaterialApp(home: SettingsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return actions;
    }

    final source = find.widgetWithText(
      ListTile,
      'Datos e imágenes: TheSportsDB',
    );

    testWidgets('menciona TheSportsDB y abre su sitio', (tester) async {
      final actions = await pumpSettings(tester);

      expect(find.text('Fuente'), findsOne);
      expect(source, findsOne);
      expect(find.text('www.thesportsdb.com'), findsOne);
      expect(
        find.text(
          'Los logos de las competiciones y los escudos de los equipos '
          'pertenecen a sus dueños.',
        ),
        findsOne,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      await tester.tap(source);
      await tester.pumpAndSettle();
      expect(actions.links, [Uri.parse('https://www.thesportsdb.com/')]);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('si no se puede abrir, lo avisa con la dirección', (
      tester,
    ) async {
      final actions = await pumpSettings(tester, linkOpens: false);

      await tester.tap(source);
      await tester.pumpAndSettle();
      expect(actions.links, hasLength(1));
      expect(
        find.text('No se pudo abrir el enlace: www.thesportsdb.com'),
        findsOne,
      );
    });

    testWidgets('texto al 200 %: sin desbordes', (tester) async {
      await pumpSettings(tester, textScale: 2);
      await tester.scrollUntilVisible(source, 200);
      await tester.pumpAndSettle();
      expect(source, findsOne);
      expect(tester.takeException(), isNull);
    });
  });
}
