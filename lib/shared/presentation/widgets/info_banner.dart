import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Tono de un aviso: decide el ícono por defecto y su color.
enum InfoTone {
  /// Información neutra (lo guardado, qué falta consultar).
  info,

  /// Datos incompletos o sin verificar, esperas.
  warning,

  /// No se pudo actualizar: se muestra lo guardado.
  offline,

  /// No se pudo cargar algo.
  error,
}

/// Aviso dentro de una vista (zonas sin verificar, descarga incompleta,
/// datos guardados…), con una acción opcional. Se anuncia a los lectores de
/// pantalla.
///
/// Todos los avisos de la app usan este widget (Hito E, §4.4): fondo
/// `surfaceContainerHigh` y el ícono del color del tono, así ninguno queda
/// fuera de la marca.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    this.icon,
    required this.text,
    this.action,
    this.tone = InfoTone.info,
    this.band = false,
  });

  /// Si es `null`, el del [tone].
  final IconData? icon;
  final String text;
  final Widget? action;
  final InfoTone tone;

  /// Franja a todo el ancho y sin bordes redondeados, que cubre también la
  /// barra de estado (el aviso de límite de consultas, arriba de la app).
  final bool band;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final palette = AppPalette.of(context);
    final (defaultIcon, iconColor) = switch (tone) {
      InfoTone.info => (Icons.info_outline, colors.primary),
      InfoTone.warning => (Icons.warning_amber, palette.warning),
      InfoTone.offline => (Icons.cloud_off, colors.onSurfaceVariant),
      InfoTone.error => (Icons.error_outline, colors.error),
    };

    Widget content = Padding(
      padding: EdgeInsets.fromLTRB(
        band ? AppSpacing.lg : AppSpacing.md,
        AppSpacing.sm,
        action == null ? (band ? AppSpacing.lg : AppSpacing.md) : AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            icon ?? defaultIcon,
            color: iconColor,
            size: AppSizes.bannerIcon,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bannerMessage.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
    if (band) content = SafeArea(bottom: false, child: content);

    return Semantics(
      liveRegion: true,
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: band ? null : AppRadius.controlAll,
        child: content,
      ),
    );
  }
}
