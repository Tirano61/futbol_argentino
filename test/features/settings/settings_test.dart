import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/storage/local_database.dart';
import 'package:futbol_argentino/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:futbol_argentino/features/settings/domain/entities/app_settings.dart';
import 'package:futbol_argentino/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:sembast/sembast_memory.dart';

import '../../helpers/recorded_app.dart';

void main() {
  late DatabaseFactory factory;
  late Database db;
  late SettingsRepositoryImpl repository;

  setUp(() async {
    factory = newDatabaseFactoryMemory();
    db = await factory.openDatabase('app.db');
    repository = SettingsRepositoryImpl(db);
  });

  tearDown(() => db.close());

  group('SettingsRepository', () {
    test('sin nada guardado: tema del sistema', () async {
      expect(await repository.read(), AppSettings.defaults);
      expect(AppSettings.defaults.theme, ThemePreference.system);
    });

    test('guarda el tema y lo conserva al volver a abrir la base', () async {
      await repository.saveTheme(ThemePreference.dark);
      await db.close();

      db = await factory.openDatabase('app.db');
      repository = SettingsRepositoryImpl(db);

      expect(
        await repository.read(),
        const AppSettings(theme: ThemePreference.dark),
      );
    });

    test('avisa cada cambio', () async {
      final seen = <ThemePreference>[];
      final subscription = repository.watch().listen((s) => seen.add(s.theme));
      await pumpEventQueue();

      await repository.saveTheme(ThemePreference.light);
      await pumpEventQueue();
      await repository.saveTheme(ThemePreference.dark);
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen, [
        ThemePreference.system,
        ThemePreference.light,
        ThemePreference.dark,
      ]);
    });

    test('un valor desconocido vuelve al tema del sistema', () async {
      await AppStores.settings.record('app').put(db, {'v': 1, 'theme': 'azul'});

      expect(await repository.read(), AppSettings.defaults);
    });
  });

  group('SettingsBloc', () {
    blocTest<SettingsBloc, SettingsState>(
      'lee lo guardado y sigue los cambios',
      build: () => SettingsBloc(settings: repository),
      act: (bloc) async {
        bloc.add(const SettingsSubscribed());
        await bloc.stream.first;
        bloc.add(const ThemePreferenceChanged(ThemePreference.dark));
      },
      expect: () => const [
        SettingsLoaded(AppSettings.defaults),
        SettingsLoaded(AppSettings(theme: ThemePreference.dark)),
      ],
    );

    test('con lo leído al abrir arranca ya cargado', () {
      final bloc = SettingsBloc(
        settings: repository,
        initial: const AppSettings(theme: ThemePreference.light),
      );
      addTearDown(bloc.close);

      expect(
        bloc.state,
        const SettingsLoaded(AppSettings(theme: ThemePreference.light)),
      );
    });
  });

  testWidgets('Ajustes: elegir «Oscuro» cambia el tema de toda la app', (
    tester,
  ) async {
    await pumpApp(tester, const Size(400, 900));
    Brightness brightness() =>
        Theme.of(tester.element(find.byType(Scaffold).last)).brightness;
    expect(brightness(), Brightness.light, reason: 'el sistema está en claro');

    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Tema'), findsOne);
    expect(find.text('Según el sistema'), findsOne);

    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);
    final selected = tester.widget<RadioGroup<ThemePreference>>(
      find.byType(RadioGroup<ThemePreference>),
    );
    expect(selected.groupValue, ThemePreference.dark);

    await tester.tap(find.byTooltip('Atrás'));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark, reason: 'vale para toda la app');
  });
}
