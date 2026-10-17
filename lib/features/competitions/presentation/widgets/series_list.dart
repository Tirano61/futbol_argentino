import 'package:flutter/material.dart';

import '../../../../shared/presentation/formatters/match_labels.dart';
import '../../../../shared/presentation/widgets/match_card.dart';
import '../../../matches/domain/entities/match.dart';
import '../../domain/usecases/watch_stage_matches.dart';

/// Etapa de ida y vuelta en el Fixture: cada serie con su encabezado
/// (equipos, global y quién avanza) y sus piernas («Ida · Martes
/// 12/08/2025»). Los partidos sin emparejar van al final.
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
    for (final s in series) ...[
      _SeriesHeader(series: s),
      for (final (i, leg) in s.tie.legs.indexed)
        legCard(leg, MatchLabels.leg(i)),
      if (s.tie.legs.length < s.tie.expectedLegs)
        _MissingLeg(label: MatchLabels.leg(s.tie.legs.length)),
    ],
    if (unpaired.isNotEmpty) ...[
      const _SectionHeader(text: 'Sin emparejar en una serie'),
      for (final m in unpaired) legCard(m, 'Partido'),
    ],
  ];
}

class _SeriesHeader extends StatelessWidget {
  const _SeriesHeader({required this.series});

  final StageSeries series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tie = series.tie;
    final outcome = series.outcome;
    final detail = [
      ?MatchLabels.aggregate(tie),
      if (outcome != null)
        MatchLabels.tieAdvances(outcome, tie)
      else if (tie.isComplete)
        'Sin dato de la definición',
    ];
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${tie.first.name} – ${tie.second.name}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (detail.isNotEmpty)
              Text(detail.join(' · '), style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MissingLeg extends StatelessWidget {
  const _MissingLeg({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Text(
      '$label: sin datos en TheSportsDB',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}
