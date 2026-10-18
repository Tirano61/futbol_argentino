import 'package:flutter/material.dart';

import '../../../features/matches/domain/entities/match.dart';
import '../../../features/matches/domain/services/match_grouping.dart';
import '../formatters/match_labels.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'match_card.dart';
import 'match_group.dart';

/// Ítems de una lista de partidos agrupados por día argentino (encabezado
/// del día + un `MatchGroup` con las filas del día), para usar dentro de un
/// `ListView`.
///
/// [newestFirst]: días del más reciente al más viejo (dentro de cada día,
/// por hora). [selectedId]: partido resaltado (abierto en el panel).
List<Widget> matchDayItems({
  required List<Match> matches,
  required DateTime now,
  String? Function(Match match)? subtitle,
  void Function(Match match)? onTap,
  bool newestFirst = false,
  int? selectedId,
}) => [
  for (final group
      in newestFirst
          ? MatchGrouping.byArgentinaDay(matches).reversed
          : MatchGrouping.byArgentinaDay(matches)) ...[
    DayHeader(group: group),
    MatchGroup(
      children: [
        for (final m in group.matches)
          MatchCard(
            key: ValueKey(m.id),
            match: m,
            now: now,
            subtitle: subtitle?.call(m),
            onTap: onTap == null ? null : () => onTap(m),
            selected: m.id == selectedId,
          ),
      ],
    ),
  ],
];

class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.group});

  final MatchDayGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Text(
          MatchLabels.day(group.day),
          style: theme.textTheme.dayHeader.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
