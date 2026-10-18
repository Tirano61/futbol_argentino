import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Superficie de un grupo de partidos (Hito E, §4.4): las filas
/// (`MatchCard`) separadas por divisores finos, con un encabezado y un pie
/// opcionales. Reemplaza «una tarjeta elevada por partido». Desde E7 es
/// también la superficie de las listas de equipos (Equipos, Favoritos) y
/// de las secciones de Ajustes.
class MatchGroup extends StatelessWidget {
  const MatchGroup({
    super.key,
    this.header,
    required this.children,
    this.footer,
  });

  /// Normalmente un [MatchGroupHeader].
  final Widget? header;
  final List<Widget> children;

  /// Normalmente un [MatchGroupFooter].
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.of(context).group,
      borderRadius: AppRadius.groupAll,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?header,
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const Divider(),
            child,
          ],
          if (footer != null) ...[
            if (children.isNotEmpty) const Divider(),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// Encabezado de un grupo: título («Fluminense – Palmeiras»), un detalle
/// opcional debajo («Global parcial…») y una acción opcional a la derecha.
/// Se anuncia como encabezado.
class MatchGroupHeader extends StatelessWidget {
  const MatchGroupHeader({
    super.key,
    required this.title,
    this.detail,
    this.trailing,
    this.detailInline = false,
  });

  final String title;
  final String? detail;
  final Widget? trailing;

  /// El detalle sigue al título en el mismo renglón, en gris («Primera
  /// División · Clausura · Fecha 12»), y baja solo si no entra.
  final bool detailInline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final titleStyle = theme.textTheme.groupTitle.copyWith(
      color: colors.onSurface,
    );
    final detail = this.detail;
    final text = detailInline && detail != null
        ? [
            Text.rich(
              TextSpan(
                text: title,
                style: titleStyle,
                children: [
                  TextSpan(
                    text: ' · $detail',
                    style: titleStyle.copyWith(
                      fontWeight: FontWeight.w400,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ]
        : [
            Text(title, style: titleStyle),
            if (detail != null)
              Text(
                detail,
                style: theme.textTheme.secondary.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
          ];
    return Semantics(
      header: true,
      child: ColoredBox(
        color: colors.surfaceContainerHigh,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.groupHeaderMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: text,
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pie de un grupo: quién clasificó en una serie («✓ Clasificó Palmeiras
/// por resultado global (3-1)», en el color de quien avanza) o por qué no
/// se sabe.
class MatchGroupFooter extends StatelessWidget {
  const MatchGroupFooter({
    super.key,
    required this.icon,
    required this.text,
    this.success = false,
  });

  final IconData icon;
  final String text;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = success
        ? AppPalette.of(context).success
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: MediaQuery.textScalerOf(context).scale(AppSizes.statusIcon),
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: success ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila tenue dentro de un grupo para algo que falta («Vuelta: sin datos
/// en TheSportsDB»).
class MatchGroupNote extends StatelessWidget {
  const MatchGroupNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
