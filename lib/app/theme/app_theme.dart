import 'package:flutter/material.dart';

/// Tema Material 3 claro y oscuro. La app sigue el modo del sistema.
abstract final class AppTheme {
  /// Celeste de la camiseta argentina como color semilla.
  static const _seed = Color(0xFF4A9BD9);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

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
