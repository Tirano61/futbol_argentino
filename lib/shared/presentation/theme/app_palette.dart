import 'package:flutter/material.dart';

/// Colores de la app (Hito E, §4.1 de `docs/HITO_E.md`; contrastes
/// verificados en `docs/evidence/e1_contrastes.md`).
///
/// El esquema sale de la semilla celeste con superficies **neutras** (sin el
/// tinte azul de `fromSeed`). Las pantallas toman los colores del esquema o
/// de [AppPalette]; nunca escriben un `Color` propio.
abstract final class AppColors {
  /// Celeste de la camiseta argentina como color semilla.
  static const seed = Color(0xFF4A9BD9);

  static ColorScheme scheme(Brightness brightness) {
    final base = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return switch (brightness) {
      Brightness.light => base.copyWith(
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
      ),
      Brightness.dark => base.copyWith(
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
      ),
    };
  }
}

/// Colores de función que el esquema de Material no tiene: la superficie de
/// los grupos y los colores que significan algo (en vivo, aviso, avanza).
///
/// Fuera de esos significados no se usan: el único color de marca es
/// `ColorScheme.primary`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.group,
    required this.live,
    required this.liveContainer,
    required this.warning,
    required this.warningContainer,
    required this.success,
  });

  /// Grupos de partidos, tablas y tarjetas de llave. En oscuro es más clara
  /// que el fondo (al revés que `surfaceContainerLowest` de Material 3).
  final Color group;

  /// Marcador y etiqueta de un partido en juego o en el entretiempo.
  final Color live;
  final Color liveContainer;

  /// Postergado, suspendido, resultado pendiente, datos incompletos.
  final Color warning;
  final Color warningContainer;

  /// Quién avanza, campeón, marcador de clasificación.
  final Color success;

  static const light = AppPalette(
    group: Color(0xFFFFFFFF),
    live: Color(0xFFC8203A),
    liveContainer: Color(0xFFFDE3E6),
    warning: Color(0xFF8A5A00),
    warningContainer: Color(0xFFFFF1D6),
    success: Color(0xFF1B7F3B),
  );

  static const dark = AppPalette(
    group: Color(0xFF171B20),
    live: Color(0xFFFF6B78),
    liveContainer: Color(0xFF4A1A20),
    warning: Color(0xFFF2B84B),
    warningContainer: Color(0xFF3D2E10),
    success: Color(0xFF5CCB82),
  );

  static AppPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// La del tema; si el tema no la trae (un widget test con el tema de
  /// fábrica), la del brillo del tema.
  static AppPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppPalette>() ?? forBrightness(theme.brightness);
  }

  @override
  AppPalette copyWith({
    Color? group,
    Color? live,
    Color? liveContainer,
    Color? warning,
    Color? warningContainer,
    Color? success,
  }) => AppPalette(
    group: group ?? this.group,
    live: live ?? this.live,
    liveContainer: liveContainer ?? this.liveContainer,
    warning: warning ?? this.warning,
    warningContainer: warningContainer ?? this.warningContainer,
    success: success ?? this.success,
  );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      group: Color.lerp(group, other.group, t)!,
      live: Color.lerp(live, other.live, t)!,
      liveContainer: Color.lerp(liveContainer, other.liveContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}
