import 'package:flutter/material.dart';

import '../../../../core/time/calendar_day.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/match_card.dart';
import '../../../../shared/presentation/widgets/match_day_list.dart';
import '../../../../shared/presentation/widgets/match_group.dart';
import '../../domain/entities/home_feed.dart';

/// Partidos de un mismo día, competición, fase y etapa: el contexto
/// («Primera División · Clausura · Fecha 12») va una sola vez, en el
/// encabezado del grupo.
final class HomeMatchGroup {
  const HomeMatchGroup({
    required this.competitionName,
    required this.detail,
    required this.matches,
  });

  final String competitionName;

  /// «Clausura · Fecha 12», «Fecha 33».
  final String detail;

  /// En orden cronológico.
  final List<HomeMatch> matches;
}

/// Los grupos de un día argentino.
final class HomeMatchDay {
  const HomeMatchDay({required this.day, required this.groups});

  /// `null`: partidos sin fecha conocida.
  final CalendarDay? day;
  final List<HomeMatchGroup> groups;
}

/// Agrupación del Inicio (solo presentación, sin consultas): por día y,
/// dentro del día, por competición · fase · etapa.
abstract final class HomeGrouping {
  /// [matches] llega en orden cronológico (`HomeFeed`). Cada partido queda
  /// en un solo grupo (un `idEvent` repetido se muestra una vez); los
  /// grupos de un día van en el orden de su primer partido y, dentro de
  /// cada grupo, los partidos conservan el orden recibido.
  static List<HomeMatchDay> byDay(List<HomeMatch> matches) {
    final days = <CalendarDay?, Map<String, List<HomeMatch>>>{};
    final seen = <int>{};
    for (final m in matches) {
      if (!seen.add(m.match.id)) continue;
      final day = m.match.kickoff.argentinaDay;
      days.putIfAbsent(day, () => {}).putIfAbsent(_key(m), () => []).add(m);
    }
    return [
      for (final MapEntry(key: day, value: groups) in days.entries)
        HomeMatchDay(
          day: day,
          groups: [
            for (final group in groups.values)
              HomeMatchGroup(
                competitionName: group.first.competitionName,
                detail: [
                  ?group.first.phaseLabel,
                  group.first.stageLabel,
                ].join(' · '),
                matches: group,
              ),
          ],
        ),
    ];
  }

  static String _key(HomeMatch m) =>
      [m.competitionName, ?m.phaseLabel, m.stageLabel].join('\u0000');
}

/// Ítems de una sección del Inicio para un `ListView` o una columna: un
/// `MatchGroup` por competición, separados por 12 px. Con [dayHeaders],
/// cada día lleva su encabezado («Domingo 18/10/2026»); sin ellos, el día
/// lo dice el título de la sección.
List<Widget> homeMatchItems({
  required List<HomeMatchDay> days,
  required DateTime now,
  required void Function(HomeMatch match) onTap,
  bool dayHeaders = true,
}) => [
  for (final (i, day) in days.indexed) ...[
    if (dayHeaders)
      DayHeader(day: day.day)
    else if (i > 0)
      const SizedBox(height: AppSpacing.md),
    for (final (j, group) in day.groups.indexed) ...[
      if (j > 0) const SizedBox(height: AppSpacing.md),
      MatchGroup(
        header: MatchGroupHeader(
          title: group.competitionName,
          detail: group.detail,
          detailInline: true,
        ),
        children: [
          for (final m in group.matches)
            MatchCard(
              key: ValueKey(m.match.id),
              match: m.match,
              now: now,
              onTap: () => onTap(m),
            ),
        ],
      ),
    ],
  ],
];

/// Mensaje de una sección sin partidos («No hay partidos hoy.»).
class HomeEmptyMessage extends StatelessWidget {
  const HomeEmptyMessage(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
