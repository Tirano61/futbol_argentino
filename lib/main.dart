import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/di/app_dependencies.dart';
import 'core/storage/local_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await LocalDatabase.openOrMemory();
  runApp(
    FutbolArgentinoApp(
      dependencies: AppDependencies.create(database: database),
    ),
  );
}
