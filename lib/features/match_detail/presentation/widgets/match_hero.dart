import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/presentation/formatters/match_labels.dart';
import '../../../../shared/presentation/layout/text_measure.dart';
import '../../../../shared/presentation/theme/app_palette.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text.dart';
import '../../../../shared/presentation/widgets/match_status_chip.dart';
import '../../../../shared/presentation/widgets/team_badge.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/entities/match_status.dart';
import '../../../matches/domain/entities/team_ref.dart';
import '../../../matches/domain/services/tie_outcome.dart';
import '../../domain/entities/match_detail.dart';
import '../formatters/match_detail_texts.dart';

/// Encabezado del detalle de un partido (Hito E, §11.2): competición y
/// etapa, día y hora de Argentina, los dos equipos con escudos de 72, el
/// marcador (o la hora) con su estado y la tanda y, en una llave, el global
/// y quién avanza.
///
/// El ganador del **partido** va en negrita (`TieOutcome.of`, como en las
/// filas de partido). Quién avanza en la **llave** se indica aparte, con ✓
/// y el texto de `MatchLabels`: pueden no coincidir (una vuelta ganada 3-2
/// que se pierde en los penales) y no se fuerza que coincidan. Sin
/// evidencia no se indica nadie.
class MatchHero extends StatelessWidget {
  const MatchHero({super.key, required this.detail, required this.now});

  final MatchDetail detail;

  /// Hora actual (UTC), para «Resultado pendiente».
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final m = detail.match;
    final overdue = m.isResultOverdue(now);
    final stage = MatchDetailTexts.phaseAndStage(detail);
    final tie = detail.tie;
    final aggregate = tie != null && tie.isSeries
        ? MatchLabels.aggregate(tie)
        : null;
    final advancement = detail.advancement;
    final secondary = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          detail.competitionName,
          textAlign: TextAlign.center,
          style: theme.textTheme.groupTitle.copyWith(color: colors.onSurface),
        ),
        // Si no entra en un renglón, cada parte («Cuartos de final»,
        // «16/09/2026 · 19:00») se mantiene junta (si entra sola): al 200 %
        // «final» o la hora quedaban solas en un renglón (E7).
        LayoutBuilder(
          builder: (context, constraints) {
            final measure = TextMeasure.of(context);
            final width = constraints.maxWidth;
            String together(List<String> parts, String separator) {
              final plain = parts.join(separator);
              if (measure.width(plain, secondary!) <= width) return plain;
              return [
                for (final part in parts)
                  measure.width(part, secondary) <= width
                      ? part.replaceAll(' ', _nbsp)
                      : part,
              ].join(separator);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (stage != null)
                  Text(
                    together(stage.split(' · '), ' · '),
                    textAlign: TextAlign.center,
                    style: secondary,
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    together(_when(m), ' '),
                    textAlign: TextAlign.center,
                    style: secondary,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _Scoreboard(match: m, overdue: overdue),
        if (aggregate != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              aggregate,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (advancement != null)
          _TieLine(
            icon: Icons.check_circle_outline,
            text: switch (tie) {
              final tie? => MatchLabels.tieAdvances(advancement, tie),
              null => MatchLabels.advances(advancement, m),
            },
            note: advancement.source != TieOutcomeSource.laterMatch
                ? null
                : tie == null
                ? 'Según los partidos guardados de la ronda siguiente.'
                : 'Según los partidos guardados posteriores de la copa.',
            success: true,
          )
        else if (tie != null && tie.isComplete)
          const _TieLine(
            icon: Icons.help_outline,
            text: 'Sin dato de la definición',
            note:
                'TheSportsDB no informa cómo se definió y ningún partido '
                'guardado posterior lo muestra.',
          ),
      ],
    );
  }

  static const _nbsp = '\u00A0';

  /// «Sábado 21/03/2026 · 14:30», en dos partes que pueden ir en renglones
  /// distintos: el día de la semana y «21/03/2026 · 14:30». Si el partido
  /// no empezó y la hora es confiable, la hora va en grande en el centro:
  /// acá, solo el día.
  static List<String> _when(Match m) {
    final day = MatchLabels.day(m.kickoff.argentinaDay);
    final timeInCenter = _Center.of(m) == _Center.time;
    final text = timeInCenter
        ? day
        : '$day · ${MatchLabels.kickoffTime(m.kickoff)}';
    final space = text.indexOf(' ');
    return space < 0
        ? [text]
        : [text.substring(0, space), text.substring(space + 1)];
  }
}

/// Qué va en el centro del héroe.
enum _Center {
  score,
  time,
  dash,
  versus;

  static _Center of(Match m) {
    if (MatchLabels.showsScore(m)) return score;
    return switch (m.status.kind) {
      MatchStatusKind.postponed ||
      MatchStatusKind.cancelled ||
      MatchStatusKind.abandoned ||
      MatchStatusKind.suspended => dash,
      _ => m.kickoff.isConfirmed ? time : versus,
    };
  }
}

/// Equipos, marcador, tanda y estado. El marcador no se parte nunca: se
/// mide con la escala de texto y, si a los costados no entran los nombres
/// sin partir palabras, los equipos van arriba en dos columnas o uno
/// debajo del otro, con el marcador entero debajo.
class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.match, required this.overdue});

  final Match match;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final palette = AppPalette.of(context);
    final m = match;
    final score = m.score;
    final center = _Center.of(m);
    final centerText = switch (center) {
      _Center.score => '${score!.home} – ${score.away}',
      _Center.time => MatchLabels.kickoffTime(m.kickoff),
      _Center.dash => '—',
      _Center.versus => 'vs',
    };
    final centerStyle = theme.textTheme.heroScore.copyWith(
      color: switch (center) {
        _Center.score when m.status.isInPlay => palette.live,
        _Center.score || _Center.time => colors.onSurface,
        _Center.dash || _Center.versus => colors.onSurfaceVariant,
      },
    );
    final shootout = center == _Center.score && m.status.isFinished
        ? MatchLabels.penalties(m)
        : null;
    final shootoutStyle = theme.textTheme.bodyMedium!.copyWith(
      color: colors.onSurface,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final status = MatchLabels.status(m.status, overdue: overdue);
    final winner = TieOutcome.of(m)?.winner.id;

    final middle = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(centerText, softWrap: false, style: centerStyle),
        if (shootout != null)
          Text(
            'Penales: $shootout',
            textAlign: TextAlign.center,
            style: shootoutStyle,
          ),
        if (status != null) ...[
          const SizedBox(height: AppSpacing.xs),
          MatchStatusChip(status: m.status, overdue: overdue),
        ],
      ],
    );

    return Semantics(
      container: true,
      label: MatchLabels.semantics(m, overdue: overdue),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final measure = TextMeasure.of(context);
          final width = constraints.maxWidth;
          final statusWidth = status == null
              ? 0.0
              // La píldora de «en vivo» va en negrita: se mide así.
              : measure.width(
                      status,
                      theme.textTheme.statusLabel.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ) +
                    measure.scaler.scale(AppSizes.statusIcon) +
                    AppSpacing.xs +
                    2 * AppSpacing.sm;
          final middleWidth = [
            measure.width(centerText, centerStyle),
            if (shootout != null)
              measure.width('Penales: $shootout', shootoutStyle),
            statusWidth,
          ].reduce(math.max);
          // Lo mínimo para un equipo en columna: el escudo y la palabra más
          // ancha de los dos nombres (en negrita, la más ancha posible).
          final team = math.max(
            AppSizes.badgeHero,
            measure.widestWord([
              m.home.name,
              m.away.name,
            ], theme.textTheme.heroTeamWinner),
          );

          Widget column(TeamRef t, {double badge = AppSizes.badgeHero}) =>
              _TeamColumn(
                team: t,
                winner: t.id == winner,
                stacked: false,
                badge: badge,
              );
          if ((width - middleWidth) / 2 - AppSpacing.md >= team) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: column(m.home)),
                const SizedBox(width: AppSpacing.md),
                SizedBox(width: middleWidth, child: middle),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: column(m.away)),
              ],
            );
          }
          // Con el marcador debajo (texto grande), escudos de 32: el
          // encabezado no se alarga más de lo necesario (E7).
          final narrowTeam = math.max(
            AppSizes.badgeHeader,
            team - AppSizes.badgeHero + AppSizes.badgeHeader,
          );
          final teams = (width - AppSpacing.md) / 2 >= narrowTeam
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: column(m.home, badge: AppSizes.badgeHeader),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: column(m.away, badge: AppSizes.badgeHeader),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TeamColumn(
                      team: m.home,
                      winner: m.home.id == winner,
                      stacked: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _TeamColumn(
                      team: m.away,
                      winner: m.away.id == winner,
                      stacked: true,
                    ),
                  ],
                );
          return Column(
            children: [
              teams,
              const SizedBox(height: AppSpacing.md),
              middle,
            ],
          );
        },
      ),
    );
  }
}

/// Un equipo: escudo de [badge] con el nombre debajo; [stacked], escudo
/// chico y nombre al lado (un equipo por renglón, local arriba).
class _TeamColumn extends StatelessWidget {
  const _TeamColumn({
    required this.team,
    required this.winner,
    required this.stacked,
    this.badge = AppSizes.badgeHero,
  });

  final TeamRef team;

  /// Ganó el partido (no necesariamente la llave).
  final bool winner;
  final bool stacked;
  final double badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        (winner ? theme.textTheme.heroTeamWinner : theme.textTheme.heroTeam)
            .copyWith(color: theme.colorScheme.onSurface);
    if (stacked) {
      return Row(
        children: [
          TeamBadge(
            name: team.name,
            url: team.badgeUrl,
            size: AppSizes.badgeHeader,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(team.name, style: style)),
        ],
      );
    }
    return Column(
      children: [
        TeamBadge(name: team.name, url: team.badgeUrl, size: badge),
        const SizedBox(height: AppSpacing.sm),
        Text(team.name, textAlign: TextAlign.center, style: style),
      ],
    );
  }
}

/// Quién avanza en la llave (✓, en el color de quien avanza) o por qué no
/// se sabe, con la nota de dónde sale la evidencia.
class _TieLine extends StatelessWidget {
  const _TieLine({
    required this.icon,
    required this.text,
    this.note,
    this.success = false,
  });

  final IconData icon;
  final String text;
  final String? note;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = success
        ? AppPalette.of(context).success
        : colors.onSurfaceVariant;
    return Semantics(
      container: true,
      label: ['Llave: $text', ?note].join('. '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: MediaQuery.textScalerOf(
                    context,
                  ).scale(AppSizes.statusIcon),
                  color: color,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: success ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ],
            ),
            if (note != null)
              Text(
                note!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
