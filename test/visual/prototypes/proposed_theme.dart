import 'package:flutter/material.dart';

/// Paleta propuesta en el Hito E (§4.1 de `docs/HITO_E.md`), solo para los
/// prototipos de E1. No es el tema de la app: el tema real se implementa en
/// E2 (`lib/app/theme`), si se aprueba.
abstract final class ProposedTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  /// Superficie de los grupos (listas de partidos, tabla, encabezados).
  static Color groupSurface(Brightness b) =>
      b == Brightness.light ? const Color(0xFFFFFFFF) : const Color(0xFF171B20);

  static ThemeData _build(Brightness brightness) {
    final light = brightness == Brightness.light;
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E6BB8),
      brightness: brightness,
    );
    final colors = light
        ? base.copyWith(
            primary: const Color(0xFF1E6BB8),
            onPrimary: const Color(0xFFFFFFFF),
            primaryContainer: const Color(0xFFD6E8F7),
            onPrimaryContainer: const Color(0xFF0B2E4F),
            surface: const Color(0xFFF3F5F8),
            onSurface: const Color(0xFF15191E),
            onSurfaceVariant: const Color(0xFF5A6470),
            surfaceContainerLowest: const Color(0xFFFFFFFF),
            surfaceContainerLow: const Color(0xFFF7F8FA),
            surfaceContainer: const Color(0xFFEEF1F5),
            surfaceContainerHigh: const Color(0xFFE8ECF1),
            surfaceContainerHighest: const Color(0xFFE1E5EA),
            outline: const Color(0xFF7D8792),
            outlineVariant: const Color(0xFFE1E5EA),
            surfaceTint: const Color(0x00000000),
          )
        : base.copyWith(
            primary: const Color(0xFF7DB8EC),
            onPrimary: const Color(0xFF06243F),
            primaryContainer: const Color(0xFF1C3A57),
            onPrimaryContainer: const Color(0xFFD6E8F7),
            surface: const Color(0xFF0F1215),
            onSurface: const Color(0xFFE6E9ED),
            onSurfaceVariant: const Color(0xFF9AA4AF),
            surfaceContainerLowest: const Color(0xFF0B0D10),
            surfaceContainerLow: const Color(0xFF171B20),
            surfaceContainer: const Color(0xFF1B2026),
            surfaceContainerHigh: const Color(0xFF232931),
            surfaceContainerHighest: const Color(0xFF2A3038),
            outline: const Color(0xFF6B7580),
            outlineVariant: const Color(0xFF2A3038),
            surfaceTint: const Color(0x00000000),
          );
    final text = ThemeData(colorScheme: colors).textTheme;
    return ThemeData(
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colors.surface,
        scrolledUnderElevation: 0,
      ),
      chipTheme: ChipThemeData(
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: colors.outlineVariant),
        selectedColor: colors.primaryContainer,
        backgroundColor: groupSurface(brightness),
        labelStyle: text.labelLarge?.copyWith(color: colors.onSurface),
        secondaryLabelStyle: text.labelLarge?.copyWith(
          color: colors.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: groupSurface(brightness),
        indicatorColor: colors.primaryContainer,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primaryContainer,
      ),
    );
  }
}
