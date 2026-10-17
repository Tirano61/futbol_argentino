import 'package:flutter/material.dart';

import '../../../features/matches/domain/entities/match.dart';
import '../../../features/matches/domain/services/tie_outcome.dart';
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
    this.showAdvance = true,
  });

  final Match match;

  /// Hora actual (UTC), para «Resultado pendiente».
  final DateTime now;

  /// Línea superior opcional (competición, fecha…).
  final String? subtitle;
  final VoidCallback? onTap;

  /// Es el partido abierto en el panel de detalle (escritorio).
  final bool selected;

  /// Muestra «Avanza X» de un empate definido por penales. `false` dentro
  /// de una serie de ida y vuelta: lo dice la serie (con el global).
  final bool showAdvance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = match.isResultOverdue(now);
    // Con un empate, quién pasó solo se sabe por la tanda (ver
    // `TieOutcome`); si se ganó en el partido, el marcador lo dice.
    final outcome = showAdvance ? TieOutcome.of(match) : null;
    final advances = outcome?.source == TieOutcomeSource.penalties
        ? MatchLabels.advances(outcome!, match)
        : null;

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
                    match.membership == MatchMembership.unconfirmed ||
                    advances != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      children: [
                        if (advances != null)
                          _Note(
                            icon: Icons.check_circle_outline,
                            text: advances,
                          ),
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

    final shootout = showScore && match.status.isFinished
        ? MatchLabels.penalties(match)
        : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        main,
        if (shootout != null)
          Text(
            '($shootout pen.)',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
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
        // «Avanza Gimnasia y Esgrima de La Plata (4-2 en penales)» no entra
        // en un renglón con texto grande.
        Flexible(child: Text(text, style: style)),
      ],
    );
  }
}
