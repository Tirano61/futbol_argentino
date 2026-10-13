import 'package:flutter/material.dart';

import '../../features/settings/domain/entities/app_settings.dart';

/// Tema Material 3 claro y oscuro. Por defecto la app sigue el modo del
/// sistema; en Ajustes se puede fijar uno.
abstract final class AppTheme {
  /// Celeste de la camiseta argentina como color semilla.
  static const _seed = Color(0xFF4A9BD9);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeMode modeFor(ThemePreference theme) => switch (theme) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };

  static ThemeData _build(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: colors,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colors.surface,
        scrolledUnderElevation: 2,
      ),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.symmetric(vertical: 4),
        clipBehavior: Clip.antiAlias,
      ),
    );
  }
}
