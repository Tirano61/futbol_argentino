import 'package:flutter/material.dart';

import '../../../features/matches/domain/entities/match.dart';
import '../../../features/matches/domain/services/match_grouping.dart';
import '../formatters/match_labels.dart';
import 'match_card.dart';

/// Ítems de una lista de partidos agrupados por día argentino (encabezado
/// del día + tarjetas), para usar dentro de un `ListView`.
List<Widget> matchDayItems({
  required List<Match> matches,
  required DateTime now,
  String? Function(Match match)? subtitle,
  void Function(Match match)? onTap,
}) => [
  for (final group in MatchGrouping.byArgentinaDay(matches)) ...[
    DayHeader(group: group),
    for (final m in group.matches)
      MatchCard(
        key: ValueKey(m.id),
        match: m,
        now: now,
        subtitle: subtitle?.call(m),
        onTap: onTap == null ? null : () => onTap(m),
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
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Text(
          MatchLabels.day(group.day),
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
