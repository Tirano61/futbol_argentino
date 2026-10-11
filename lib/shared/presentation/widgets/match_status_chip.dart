import 'package:flutter/material.dart';

import '../../../features/matches/domain/entities/match_status.dart';
import '../formatters/match_labels.dart';

/// Etiqueta de estado: «En juego», «Final (penales)», «Postergado»…
/// No muestra nada para un partido programado (salvo resultado pendiente).
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

    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status.kind) {
      MatchStatusKind.live || MatchStatusKind.halfTime => (
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      MatchStatusKind.finished => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
      MatchStatusKind.scheduled => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      _ => (colors.tertiaryContainer, colors.onTertiaryContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
