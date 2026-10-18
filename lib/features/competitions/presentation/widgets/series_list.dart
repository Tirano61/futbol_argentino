import 'package:flutter/material.dart';

import '../../../../shared/presentation/formatters/match_labels.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/match_card.dart';
import '../../../../shared/presentation/widgets/match_group.dart';
import '../../../../shared/presentation/widgets/section_header.dart';
import '../../../matches/domain/entities/match.dart';
import '../../domain/usecases/watch_stage_matches.dart';

/// Etapa de ida y vuelta en el Fixture: un grupo por serie, con los equipos
/// y el global en el encabezado, sus piernas («Ida · Martes 12/08/2025») y
/// quién avanza al pie. Los partidos sin emparejar van al final.
List<Widget> seriesItems({
  required List<StageSeries> series,
  required List<Match> unpaired,
  required DateTime now,
  required void Function(Match match) onTap,
  int? selectedId,
}) {
  Widget legCard(Match m, String label) => MatchCard(
    key: ValueKey(m.id),
    match: m,
    now: now,
    subtitle: '$label · ${MatchLabels.day(m.kickoff.argentinaDay)}',
    onTap: () => onTap(m),
    selected: m.id == selectedId,
    showAdvance: false,
  );

  return [
    for (final s in series)
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: MatchGroup(
          header: MatchGroupHeader(
            title: '${s.tie.first.name} – ${s.tie.second.name}',
            detail: MatchLabels.aggregate(s.tie),
          ),
          footer: _seriesFooter(s),
          children: [
            for (final (i, leg) in s.tie.legs.indexed)
              legCard(leg, MatchLabels.leg(i)),
            if (s.tie.legs.length < s.tie.expectedLegs)
              MatchGroupNote(
                '${MatchLabels.leg(s.tie.legs.length)}: sin datos en '
                'TheSportsDB',
              ),
          ],
        ),
      ),
    if (unpaired.isNotEmpty) ...[
      const SectionHeader(title: 'Sin emparejar en una serie'),
      MatchGroup(children: [for (final m in unpaired) legCard(m, 'Partido')]),
    ],
  ];
}

/// Quién avanza (con el global o la tanda), o que la serie terminó sin
/// evidencia de la definición. Mientras se juega, nada.
Widget? _seriesFooter(StageSeries series) {
  final tie = series.tie;
  final outcome = series.outcome;
  if (outcome != null) {
    return MatchGroupFooter(
      icon: Icons.check_circle_outline,
      text: MatchLabels.tieAdvances(outcome, tie),
      success: true,
    );
  }
  if (tie.isComplete) {
    return const MatchGroupFooter(
      icon: Icons.help_outline,
      text: 'Sin dato de la definición',
    );
  }
  return null;
}
