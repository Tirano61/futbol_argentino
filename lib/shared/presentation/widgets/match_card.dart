import 'package:flutter/material.dart';

import '../../../features/matches/domain/entities/match.dart';
import '../formatters/match_labels.dart';
import 'match_status_chip.dart';
import 'team_badge.dart';

/// Tarjeta de partido: local · marcador u horario · visitante.
class MatchCard extends StatelessWidget {
  const MatchCard({
    super.key,
    required this.match,
    required this.now,
    this.subtitle,
    this.onTap,
    this.selected = false,
  });

  final Match match;

  /// Hora actual (UTC), para «Resultado pendiente».
  final DateTime now;

  /// Línea superior opcional (competición, fecha…).
  final String? subtitle;
  final VoidCallback? onTap;

  /// Es el partido abierto en el panel de detalle (escritorio).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = match.isResultOverdue(now);

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: MatchLabels.semantics(match, overdue: overdue),
      excludeSemantics: true,
      child: Card(
        color: selected ? theme.colorScheme.secondaryContainer : null,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: _TeamSide(
                        name: match.home.name,
                        badgeUrl: match.home.badgeUrl,
                        alignEnd: true,
                      ),
                    ),
                    SizedBox(
                      width: 104,
                      child: _Center(match: match, overdue: overdue),
                    ),
                    Expanded(
                      child: _TeamSide(
                        name: match.away.name,
                        badgeUrl: match.away.badgeUrl,
                        alignEnd: false,
                      ),
                    ),
                  ],
                ),
                if (match.wasRescheduled ||
                    match.membership == MatchMembership.unconfirmed)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      children: [
                        if (match.wasRescheduled)
                          const _Note(icon: Icons.update, text: 'Reprogramado'),
                        if (match.membership == MatchMembership.unconfirmed)
                          const _Note(
                            icon: Icons.help_outline,
                            text: 'La API ya no lo lista en esta fecha',
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamSide extends StatelessWidget {
  const _TeamSide({
    required this.name,
    required this.badgeUrl,
    required this.alignEnd,
  });

  final String name;
  final String? badgeUrl;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final text = Flexible(
      child: Text(
        name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
    final badge = TeamBadge(name: name, url: badgeUrl);
    return Row(
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: alignEnd
          ? [text, const SizedBox(width: 8), badge]
          : [badge, const SizedBox(width: 8), text],
    );
  }
}

class _Center extends StatelessWidget {
  const _Center({required this.match, required this.overdue});

  final Match match;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = match.score;
    final showScore =
        score != null && (match.status.isFinished || match.status.isInPlay);

    final Widget main;
    if (showScore) {
      main = Text(
        '${score.home} – ${score.away}',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: match.status.isInPlay ? theme.colorScheme.error : null,
        ),
      );
    } else if (match.kickoff.isConfirmed) {
      main = Text(
        MatchLabels.kickoffTime(match.kickoff),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      );
    } else {
      main = Text(
        MatchLabels.unconfirmedTime,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        main,
        const SizedBox(height: 4),
        MatchStatusChip(status: match.status, overdue: overdue),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: style?.color),
        const SizedBox(width: 4),
        Text(text, style: style),
      ],
    );
  }
}
