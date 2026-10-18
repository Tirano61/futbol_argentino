import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../features/matches/domain/entities/match.dart';
import '../../../features/matches/domain/entities/match_status.dart';
import '../../../features/matches/domain/entities/team_ref.dart';
import '../../../features/matches/domain/services/tie_outcome.dart';
import '../formatters/match_labels.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'match_status_chip.dart';
import 'team_badge.dart';

/// Fila de partido (Hito E, §5.1): local · marcador u horario · visitante.
/// Va dentro de un `MatchGroup`, que pone la superficie y los divisores.
///
/// La altura sale del contenido (56 es solo el mínimo): nunca se recorta un
/// marcador, una hora, una tanda ni un estado. El nombre de un equipo va en
/// hasta dos renglones (completo en la semántica y en el detalle). Si a los
/// costados del marcador no entra un nombre (texto grande en un teléfono),
/// los equipos van uno debajo del otro, con los goles a la derecha.
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

  /// Contexto opcional arriba a la izquierda (competición, fecha…). En las
  /// listas agrupadas se omite: lo dice el encabezado del grupo o del día.
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
    final colors = theme.colorScheme;
    final overdue = match.isResultOverdue(now);
    // Ganador en negrita solo con evidencia: el marcador o la tanda que
    // informa la API (`TieOutcome`).
    final outcome = TieOutcome.of(match);
    // Con un empate, quién pasó solo se sabe por la tanda; si se ganó en el
    // partido, el marcador lo dice.
    final advances =
        showAdvance && outcome?.source == TieOutcomeSource.penalties
        ? MatchLabels.advances(outcome!, match)
        : null;
    final notes = [
      if (advances != null)
        _Note(icon: Icons.check_circle_outline, text: advances, success: true),
      if (match.wasRescheduled)
        const _Note(icon: Icons.update, text: 'Reprogramado'),
      if (match.membership == MatchMembership.unconfirmed)
        const _Note(
          icon: Icons.help_outline,
          text: 'La API ya no lo lista en esta fecha',
        ),
    ];

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              subtitle!,
              style: theme.textTheme.secondary.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final metrics = _RowMetrics.of(context);
            final teams = _Teams(
              match: match,
              overdue: overdue,
              winner: outcome?.winner,
              metrics: metrics,
            );
            return metrics.fitsSideBySide(constraints.maxWidth)
                ? _SideBySide(teams)
                : _Stacked(teams);
          },
        ),
        if (notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: notes,
            ),
          ),
      ],
    );

    // La fila elegida: fondo de marca y una barra a la izquierda (la señal
    // no es solo el color).
    final bar = selected ? AppSizes.selectionBar : 0.0;
    return Semantics(
      button: onTap != null,
      // La fila excluye la semántica de sus hijos (`InkWell`): la acción
      // de tocar va acá, para los lectores de pantalla.
      onTap: onTap,
      selected: selected,
      label: MatchLabels.semantics(match, overdue: overdue),
      excludeSemantics: true,
      child: Material(
        type: selected ? MaterialType.canvas : MaterialType.transparency,
        color: selected ? colors.primaryContainer : null,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: selected
                ? BoxDecoration(
                    border: Border(
                      left: BorderSide(color: colors.primary, width: bar),
                    ),
                  )
                : const BoxDecoration(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.matchRowMinHeight,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md - bar,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Anchos de la fila que dependen de la escala de texto (se miden una vez
/// por escala y tema).
final class _RowMetrics {
  const _RowMetrics({
    required this.centerMin,
    required this.centerMax,
    required this.goals,
    required this.minName,
  });

  /// Columna central: lo que ocupa un marcador de un dígito o una hora, así
  /// las filas quedan alineadas…
  final double centerMin;

  /// …y hasta el marcador más ancho posible («00 – 00»), o «Horario por»
  /// (§5.2: «Horario por confirmar» en dos renglones).
  final double centerMax;

  /// Goles de un equipo con los equipos apilados («00»).
  final double goals;

  /// Ancho mínimo de un nombre a los costados del marcador: unas diez
  /// letras por renglón. Con menos, «Independiente» se partiría.
  final double minName;

  static (Object, _RowMetrics)? _cache;

  static _RowMetrics of(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final text = Theme.of(context).textTheme;
    final key = (scaler, text.listScore, text.listTime, text.labelSmall);
    if (_cache case (final cachedKey, final metrics) when cachedKey == key) {
      return metrics;
    }

    double measure(String value, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width.ceilToDouble();
    }

    final centerMin = math.max(
      measure('0 – 0', text.listScore),
      measure('00:00', text.listTime),
    );
    final metrics = _RowMetrics(
      centerMin: centerMin,
      centerMax: [
        centerMin,
        measure('00 – 00', text.listScore),
        measure('Horario por', text.labelSmall!),
      ].reduce(math.max),
      goals: measure('00', text.listScore),
      minName: scaler.scale(text.teamName.fontSize!) * 5.5,
    );
    _cache = (key, metrics);
    return metrics;
  }

  /// Entre el escudo y el marcador: 4 en vez de 8, así a 360 px entra
  /// «Independiente» (91,5 px con Roboto) sin partirse.
  static const centerGap = AppSpacing.xs;

  /// Si en [width] los nombres entran a los costados del marcador.
  bool fitsSideBySide(double width) {
    final name =
        (width - centerMax - 2 * centerGap) / 2 -
        AppSizes.badgeRow -
        AppSpacing.sm;
    return name >= minName;
  }
}

/// Lo que muestran las dos disposiciones de la fila.
final class _Teams {
  const _Teams({
    required this.match,
    required this.overdue,
    required this.winner,
    required this.metrics,
  });

  final Match match;
  final bool overdue;
  final TeamRef? winner;
  final _RowMetrics metrics;

  bool get showsScore => MatchLabels.showsScore(match);

  bool isWinner(TeamRef team) => team.id == winner?.id;

  /// «(4-3 pen.)», si la API informa la tanda de un partido terminado.
  String? get shootout => showsScore && match.status.isFinished
      ? MatchLabels.penalties(match)
      : null;

  bool get hasStatus =>
      MatchLabels.status(match.status, overdue: overdue) != null;

  /// Sin marcador: la hora, «Horario por confirmar» o «—» (postergado,
  /// cancelado, o suspendido sin parcial).
  Widget timeOrDash(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dash = switch (match.status.kind) {
      MatchStatusKind.postponed ||
      MatchStatusKind.cancelled ||
      MatchStatusKind.abandoned ||
      MatchStatusKind.suspended => true,
      _ => false,
    };
    if (dash) {
      return Text(
        '—',
        textAlign: TextAlign.center,
        style: theme.textTheme.listScore.copyWith(
          color: colors.onSurfaceVariant,
        ),
      );
    }
    if (match.kickoff.isConfirmed) {
      return Text(
        MatchLabels.kickoffTime(match.kickoff),
        textAlign: TextAlign.center,
        // Resultado pendiente: la hora en gris, el aviso debajo.
        style: theme.textTheme.listTime.copyWith(
          color: overdue ? colors.onSurfaceVariant : colors.onSurface,
        ),
      );
    }
    return Text(
      MatchLabels.unconfirmedTime,
      textAlign: TextAlign.center,
      style: theme.textTheme.labelSmall?.copyWith(
        color: colors.onSurfaceVariant,
      ),
    );
  }

  Color scoreColor(BuildContext context) => match.status.isInPlay
      ? AppPalette.of(context).live
      : Theme.of(context).colorScheme.onSurface;

  Widget shootoutText(BuildContext context, String shootout) {
    final theme = Theme.of(context);
    return Text(
      '($shootout pen.)',
      textAlign: TextAlign.center,
      style: theme.textTheme.statusLabel.copyWith(
        fontWeight: FontWeight.w400,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget status() => MatchStatusChip(status: match.status, overdue: overdue);
}

/// Local · centro · visitante, con el estado centrado debajo.
class _SideBySide extends StatelessWidget {
  const _SideBySide(this.teams);

  final _Teams teams;

  @override
  Widget build(BuildContext context) {
    final match = teams.match;
    final score = match.score;
    final shootout = teams.shootout;
    final center = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (teams.showsScore && score != null)
          Text(
            '${score.home} – ${score.away}',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.listScore.copyWith(color: teams.scoreColor(context)),
          )
        else
          teams.timeOrDash(context),
        if (shootout != null) teams.shootoutText(context, shootout),
      ],
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TeamSide(
                team: match.home,
                winner: teams.isWinner(match.home),
                alignEnd: true,
              ),
            ),
            const SizedBox(width: _RowMetrics.centerGap),
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: teams.metrics.centerMin,
                maxWidth: teams.metrics.centerMax,
              ),
              child: center,
            ),
            const SizedBox(width: _RowMetrics.centerGap),
            Expanded(
              child: _TeamSide(
                team: match.away,
                winner: teams.isWinner(match.away),
                alignEnd: false,
              ),
            ),
          ],
        ),
        if (teams.hasStatus)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: teams.status(),
          ),
      ],
    );
  }
}

class _TeamSide extends StatelessWidget {
  const _TeamSide({
    required this.team,
    required this.winner,
    required this.alignEnd,
  });

  final TeamRef team;
  final bool winner;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final name = Flexible(
      child: _TeamName(team: team, winner: winner, alignEnd: alignEnd),
    );
    final badge = TeamBadge(
      name: team.name,
      url: team.badgeUrl,
      size: AppSizes.badgeRow,
    );
    return Row(
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: alignEnd
          ? [name, const SizedBox(width: AppSpacing.sm), badge]
          : [badge, const SizedBox(width: AppSpacing.sm), name],
    );
  }
}

class _TeamName extends StatelessWidget {
  const _TeamName({
    required this.team,
    required this.winner,
    this.alignEnd = false,
  });

  final TeamRef team;
  final bool winner;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      team.name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      style:
          (winner ? theme.textTheme.teamNameWinner : theme.textTheme.teamName)
              .copyWith(color: theme.colorScheme.onSurface),
    );
  }
}

/// Equipos uno debajo del otro, con los goles (o la hora) a la derecha, y
/// la tanda y el estado debajo.
class _Stacked extends StatelessWidget {
  const _Stacked(this.teams);

  final _Teams teams;

  @override
  Widget build(BuildContext context) {
    final match = teams.match;
    final score = teams.showsScore ? match.score : null;
    final shootout = teams.shootout;

    Widget line(TeamRef team, int? goals) => Row(
      children: [
        TeamBadge(name: team.name, url: team.badgeUrl, size: AppSizes.badgeRow),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _TeamName(team: team, winner: teams.isWinner(team)),
        ),
        if (goals != null) ...[
          const SizedBox(width: AppSpacing.sm),
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: teams.metrics.goals),
            child: Text(
              '$goals',
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.listScore.copyWith(color: teams.scoreColor(context)),
            ),
          ),
        ],
      ],
    );

    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line(match.home, score?.home),
        const SizedBox(height: AppSpacing.xs),
        line(match.away, score?.away),
      ],
    );
    final below = [
      if (shootout != null) teams.shootoutText(context, shootout),
      if (teams.hasStatus) teams.status(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (score != null)
          lines
        else
          Row(
            children: [
              Expanded(child: lines),
              const SizedBox(width: AppSpacing.sm),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: teams.metrics.centerMax),
                child: teams.timeOrDash(context),
              ),
            ],
          ),
        if (below.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.xs,
              left: AppSizes.badgeRow + AppSpacing.sm,
            ),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: below,
            ),
          ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, this.success = false});

  final IconData icon;
  final String text;

  /// «Avanza X»: en el color de función de quien avanza.
  final bool success;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = success
        ? AppPalette.of(context).success
        : theme.colorScheme.onSurfaceVariant;
    final style = theme.textTheme.secondary.copyWith(
      color: color,
      fontWeight: success ? FontWeight.w600 : null,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: MediaQuery.textScalerOf(context).scale(AppSizes.statusIcon),
          color: color,
        ),
        const SizedBox(width: AppSpacing.xs),
        // «Avanza Gimnasia y Esgrima de La Plata (4-2 en penales)» no entra
        // en un renglón con texto grande.
        Flexible(child: Text(text, style: style)),
      ],
    );
  }
}
