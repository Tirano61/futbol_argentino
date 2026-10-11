import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/di/app_dependencies.dart';

void main() {
  runApp(FutbolArgentinoApp(dependencies: AppDependencies.create()));
}
