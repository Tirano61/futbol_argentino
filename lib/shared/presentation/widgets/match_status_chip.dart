import 'package:flutter/material.dart';

import '../../../features/matches/domain/entities/match_status.dart';
import '../formatters/match_labels.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Etiqueta de estado de un partido (Hito E, §5.2). No muestra nada para un
/// partido programado (salvo resultado pendiente).
///
/// El estado nunca depende solo del color: siempre lleva el texto, en vivo
/// un punto fijo y en las anomalías un ícono. «Final» es texto gris, sin
/// píldora: la píldora queda para en juego y entretiempo.
class MatchStatusChip extends StatelessWidget {
  const MatchStatusChip({
    super.key,
    required this.status,
    this.overdue = false,
  });

  final MatchStatus status;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final label = MatchLabels.status(status, overdue: overdue);
    if (label == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final palette = AppPalette.of(context);
    final style = theme.textTheme.statusLabel;

    return switch (status.kind) {
      MatchStatusKind.live || MatchStatusKind.halfTime => _LivePill(
        label: label,
        color: palette.live,
        background: palette.liveContainer,
        style: style,
      ),
      MatchStatusKind.scheduled => _IconLabel(
        icon: Icons.hourglass_empty,
        label: label,
        color: palette.warning,
        style: style,
      ),
      MatchStatusKind.postponed => _IconLabel(
        icon: Icons.event_busy,
        label: label,
        color: palette.warning,
        style: style,
      ),
      MatchStatusKind.abandoned || MatchStatusKind.suspended => _IconLabel(
        icon: Icons.pause_circle_outline,
        label: label,
        color: palette.warning,
        style: style,
      ),
      MatchStatusKind.cancelled => _IconLabel(
        icon: Icons.block,
        label: label,
        color: colors.error,
        style: style,
      ),
      MatchStatusKind.finished || MatchStatusKind.unknown => Text(
        label,
        textAlign: TextAlign.center,
        style: style.copyWith(color: colors.onSurfaceVariant),
      ),
    };
  }
}

/// «● En juego»: el punto es fijo (una animación infinita trabaría los
/// `pumpAndSettle` de los tests).
class _LivePill extends StatelessWidget {
  const _LivePill({
    required this.label,
    required this.color,
    required this.background,
    required this.style,
  });

  final String label;
  final Color color;
  final Color background;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pillAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: AppSizes.liveDot,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: style.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ícono + texto del color del tono (aviso o error). El texto se parte en
/// renglones si no entra (texto al 200 %).
class _IconLabel extends StatelessWidget {
  const _IconLabel({
    required this.icon,
    required this.label,
    required this.color,
    required this.style,
  });

  final IconData icon;
  final String label;
  final Color color;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final iconSize = MediaQuery.textScalerOf(
      context,
    ).scale(AppSizes.statusIcon);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: color),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(label, style: style.copyWith(color: color)),
        ),
      ],
    );
  }
}
