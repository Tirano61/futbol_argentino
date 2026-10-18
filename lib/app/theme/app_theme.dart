import 'package:flutter/material.dart';

import '../../features/settings/domain/entities/app_settings.dart';
import '../../shared/presentation/theme/app_palette.dart';
import '../../shared/presentation/theme/app_spacing.dart';

/// Tema Material 3 claro y oscuro (Hito E, §4). Por defecto la app sigue el
/// modo del sistema; en Ajustes se puede fijar uno.
///
/// Los criterios visuales van en los temas de componentes, para no repetir
/// estilos en cada widget: contenido sin elevación (la separación sale de
/// la superficie), chips sin tilde, divisores de 1 px.
abstract final class AppTheme {
  /// Opacidad del contenido de un control deshabilitado (Material 3).
  static const _disabledAlpha = 0.38;

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeMode modeFor(ThemePreference theme) => switch (theme) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };

  static ThemeData _build(Brightness brightness) {
    final colors = AppColors.scheme(brightness);
    final palette = AppPalette.forBrightness(brightness);
    final text = ThemeData(colorScheme: colors).textTheme;

    // Deshabilitado, como Material 3 (el color fijo valía también para ese
    // estado y un chip inactivo se veía activo; E7).
    final chipLabel = text.labelLarge!.copyWith(
      color: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colors.onSurface.withValues(alpha: _disabledAlpha)
            : colors.onSurface,
      ),
    );
    final chipSelectedLabel = chipLabel.copyWith(
      color: colors.onPrimaryContainer,
      fontWeight: FontWeight.w700,
    );

    return ThemeData(
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.group,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.groupAll),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        clipBehavior: Clip.antiAlias,
      ),
      // Las chips de la app son `ChoiceChip`: el elegido toma
      // `secondarySelectedColor` y `secondaryLabelStyle`.
      chipTheme: ChipThemeData(
        showCheckmark: false,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.controlAll),
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BorderSide.none
              : BorderSide(color: colors.outlineVariant),
        ),
        backgroundColor: palette.group,
        selectedColor: colors.primaryContainer,
        secondarySelectedColor: colors.primaryContainer,
        labelStyle: chipLabel,
        secondaryLabelStyle: chipSelectedLabel,
        iconTheme: IconThemeData(color: colors.onSurfaceVariant),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: AppSizes.divider,
        space: AppSizes.divider,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.group,
        indicatorColor: colors.primaryContainer,
        // Etiquetas de fábrica: en negrita, «Competiciones» no entra en
        // un renglón a 360 px.
        elevation: 0,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primaryContainer,
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: palette.group),
    );
  }
}
