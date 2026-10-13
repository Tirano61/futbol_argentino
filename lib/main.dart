import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/di/app_dependencies.dart';
import 'core/storage/local_database.dart';
import 'features/settings/domain/entities/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await LocalDatabase.openOrMemory();
  final dependencies = AppDependencies.create(database: database);
  runApp(
    FutbolArgentinoApp(
      dependencies: dependencies,
      initialSettings: await _readSettings(dependencies),
    ),
  );
}

/// Los ajustes se leen antes del primer cuadro para que el tema elegido no
/// parpadee al abrir. Si la base no responde, se arranca con lo
/// predeterminado y el `SettingsBloc` los toma cuando lleguen.
Future<AppSettings?> _readSettings(AppDependencies dependencies) async {
  try {
    return await dependencies.settingsRepository.read().timeout(
      const Duration(seconds: 2),
    );
  } catch (e) {
    debugPrint('Ajustes: no se pudieron leer al abrir ($e).');
    return null;
  }
}
