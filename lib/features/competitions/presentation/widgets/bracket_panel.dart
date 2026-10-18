import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/sync/sync_progress.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/presentation/formatters/failure_messages.dart';
import '../../../../shared/presentation/formatters/match_labels.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/info_banner.dart';
import '../../../../shared/presentation/widgets/match_card.dart';
import '../../../../shared/presentation/widgets/match_group.dart';
import '../../../../shared/presentation/widgets/scroll_row.dart';
import '../../../../shared/presentation/widgets/status_views.dart';
import '../../../../shared/presentation/widgets/team_badge.dart';
import '../../../matches/domain/entities/knockout_tie.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/entities/team_ref.dart';
import '../../domain/catalog/competition_catalog.dart';
import '../../domain/entities/phase.dart';
import '../../domain/knockout/knockout_bracket.dart';
import '../../domain/usecases/watch_knockout_bracket.dart';
import '../bloc/bracket_bloc.dart';

/// Vista «Llaves» de una competición: selector de torneo (Primera), avance
/// de la descarga, el cuadro, las series previas (Playoffs de la
/// Sudamericana) y los partidos que no se pudieron ubicar.
class BracketPanel extends StatelessWidget {
  const BracketPanel({
    super.key,
    required this.phase,
    required this.onPhaseSelected,
    required this.onRefresh,
  });

  /// Torneo elegido (`null` o si no es de la competición: el último con
  /// eliminatorias).
  final PhaseKey? phase;
  final ValueChanged<PhaseKey> onPhaseSelected;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BracketBloc, BracketState>(
      builder: (context, state) => switch (state) {
        BracketInitial() || BracketLoading() => Center(
          child: Semantics(
            label: 'Cargando llaves',
            child: const CircularProgressIndicator(),
          ),
        ),
        BracketFailure(:final failure) => ErrorView(
          failure: failure,
          onRetry: () =>
              context.read<BracketBloc>().add(const BracketRefreshRequested()),
        ),
        BracketUnavailable(:final view) => EmptyView(
          icon: Icons.account_tree_outlined,
          title: 'Sin cuadro de llaves',
          message:
              'Todavía no hay un cuadro verificado para '
              '${CompetitionCatalog.byId(view.competitionId)?.name ?? 'esta competición'}.',
        ),
        BracketLoaded(:final view, :final isRefreshing) => _LoadedView(
          view: view,
          isRefreshing: isRefreshing,
          phase: phase,
          onPhaseSelected: onPhaseSelected,
          onRefresh: onRefresh,
        ),
      },
    );
  }
}

class _LoadedView extends StatefulWidget {
  const _LoadedView({
    required this.view,
    required this.isRefreshing,
    required this.phase,
    required this.onPhaseSelected,
    required this.onRefresh,
  });

  final BracketView view;
  final bool isRefreshing;
  final PhaseKey? phase;
  final ValueChanged<PhaseKey> onPhaseSelected;
  final Future<void> Function() onRefresh;

  @override
  State<_LoadedView> createState() => _LoadedViewState();
}

class _LoadedViewState extends State<_LoadedView> {
  /// Ronda desde la que se muestra el cuadro; `null`: la primera con 8
  /// partidos o menos (en la Copa, octavos: 32avos no entran a lo ancho).
  int? _start;

  static const _defaultMaxSlots = 8;

  @override
  void didUpdateWidget(_LoadedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view.competitionId != widget.view.competitionId ||
        oldWidget.view.season != widget.view.season ||
        oldWidget.phase != widget.phase) {
      _start = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final definition = CompetitionCatalog.byId(view.competitionId);
    final phases = definition?.bracketPhases ?? const <PhaseKey>[];
    final requested = widget.phase;
    final phase = requested != null && phases.contains(requested)
        ? requested
        : phases.lastWhere(
            (p) => view.brackets[p]?.hasMatches ?? false,
            orElse: () => phases.isEmpty ? PhaseKey.unica : phases.first,
          );
    final bracket = view.brackets[phase];
    final rounds = bracket != null && bracket.hasMatches
        ? bracket.rounds
        : const <BracketRoundView>[];
    final start = rounds.isEmpty
        ? 0
        : (_start ??
                  rounds.indexWhere((r) => r.slots.length <= _defaultMaxSlots))
              .clamp(0, rounds.length - 1);

    // Filtros de la vista (nivel 3 de la cabecera, Hito E): el torneo y la
    // ronda desde la que se dibuja el cuadro, en una fila fija que se
    // desplaza, con lo elegido a la vista.
    final theme = Theme.of(context);
    final filters = <Widget>[];
    int? visible;
    if (phases.length > 1) {
      for (final p in phases) {
        if (p == phase) visible = filters.length;
        filters.add(
          ChoiceChip(
            label: Text(p.label),
            selected: p == phase,
            onSelected: (_) => widget.onPhaseSelected(p),
          ),
        );
      }
    }
    if (rounds.length > 4) {
      filters.add(Text('Desde', style: theme.textTheme.labelLarge));
      for (final (i, r) in rounds.indexed.take(rounds.length - 1)) {
        if (i == start && visible == null) visible = filters.length;
        filters.add(
          ChoiceChip(
            label: Text(r.label),
            selected: i == start,
            onSelected: (_) => setState(() => _start = i),
          ),
        );
      }
    }

    final list = RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(12, filters.isEmpty ? 8 : 0, 12, 24),
        children: [
          if (widget.isRefreshing) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
          ],
          _SyncStatus(progress: view.progress),
          if (bracket == null || !bracket.hasMatches)
            EmptyView(
              icon: Icons.account_tree_outlined,
              title: 'Sin eliminatorias',
              message:
                  'Todavía no hay partidos de eliminación '
                  '${_of(definition, phase)} ${view.season.apiValue} en '
                  'TheSportsDB.',
            )
          else
            ..._bracketItems(
              context,
              bracket,
              start: start,
              continental: definition?.rules is ContinentalCupRules,
            ),
        ],
      ),
    );
    if (filters.isEmpty) return list;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: ScrollRow(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            visible: visible,
            children: filters,
          ),
        ),
        Expanded(child: list),
      ],
    );
  }

  /// «del Clausura», «de la Copa Argentina», «de la Copa Libertadores».
  static String _of(CompetitionDefinition? definition, PhaseKey phase) =>
      phase == PhaseKey.unica ||
          phase == PhaseKey.knockoutStage ||
          definition == null
      ? 'de la ${definition?.name ?? 'competición'}'
      : 'del ${phase.label}';

  /// [continental]: copa internacional (series de ida y vuelta; una llave
  /// terminada sin evidencia de quién avanzó lo dice).
  List<Widget> _bracketItems(
    BuildContext context,
    KnockoutBracket bracket, {
    required int start,
    required bool continental,
  }) {
    final theme = Theme.of(context);
    final rounds = bracket.rounds;
    final shown = rounds.sublist(start);
    final champion = rounds.last.slots.firstOrNull?.outcome?.winner;
    final now = context.read<Clock>().now();

    return [
      if (champion != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _ChampionBanner(team: champion),
        ),
      if (shown.any((r) => r.pairingUnknown))
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: InfoBanner(
            tone: InfoTone.warning,
            icon: Icons.info_outline,
            text:
                'Faltan partidos de la ronda siguiente en TheSportsDB: '
                'algunas llaves van por fecha, sin unir.',
          ),
        ),
      const SizedBox(height: 12),
      // Entra a lo ancho si hay lugar; si no, se desplaza.
      LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _BracketCanvas(
            rounds: shown,
            availableWidth: constraints.maxWidth,
            explainUndecided: continental,
          ),
        ),
      ),
      for (final round in bracket.preliminary)
        if (round.hasMatches) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Semantics(
              header: true,
              child: Text(round.label, style: theme.textTheme.titleMedium),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'Sus ganadores juegan los octavos de final.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth < _BracketCanvas.maxColumnWidth
                  ? constraints.maxWidth
                  : _BracketCanvas.maxColumnWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final slot in round.slots)
                    SizedBox(
                      width: width,
                      height: _BracketCanvas.cardHeight(context),
                      child: _TieCard(
                        slot: slot,
                        round: round.label,
                        explainUndecided: continental,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      if (bracket.unplaced.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Semantics(
            header: true,
            child: Text(
              'Sin ubicar en el cuadro',
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
        MatchGroup(
          children: [
            for (final m in bracket.unplaced)
              MatchCard(
                match: m,
                now: now,
                onTap: () => context.push(AppRoutes.matchDetail(m.id)),
              ),
          ],
        ),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
        child: Text(
          rounds.any((r) => r.legs > 1)
              ? 'Las series de ida y vuelta las gana quien hace más goles en '
                    'el global y, si empatan, la tanda de penales (sin '
                    'alargue ni gol de visitante); la final se juega a un '
                    'partido. Si TheSportsDB no informa la tanda, avanza el '
                    'equipo que juega después en la copa; sin esa evidencia, '
                    'no se indica.'
              : 'Cada llave se juega a un partido. Avanza quien gana el '
                    'partido o la tanda de penales; si TheSportsDB no informa '
                    'la tanda, el equipo que juega la ronda siguiente.',
          style: theme.textTheme.bodySmall,
        ),
      ),
    ];
  }
}

class _ChampionBanner extends StatelessWidget {
  const _ChampionBanner({required this.team});

  final TeamRef team;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: 'Campeón: ${team.name}',
      excludeSemantics: true,
      child: Card(
        color: colors.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.emoji_events_outlined,
                color: colors.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              TeamBadge(name: team.name, url: team.badgeUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Campeón: ${team.name}',
                  style: text.titleMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avance no bloqueante de la descarga, o por qué se detuvo.
class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.progress});

  final SyncProgress progress;

  @override
  Widget build(BuildContext context) {
    final failure = progress.failure;
    final rounds = 'Rondas consultadas ${progress.done} de ${progress.total}';
    if (progress.isRunning) {
      return Semantics(
        liveRegion: true,
        label: rounds,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: progress.total == 0
                    ? null
                    : progress.done / progress.total,
              ),
              const SizedBox(height: 4),
              Text(rounds, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      );
    }
    if (failure == null) return const SizedBox.shrink();
    final (:title, message: _) = failureMessage(failure);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InfoBanner(
        tone: InfoTone.offline,
        icon: Icons.cloud_off,
        text:
            'No se pudieron consultar todas las rondas '
            '(${progress.done} de ${progress.total}). $title',
        action: TextButton(
          onPressed: () =>
              context.read<BracketBloc>().add(const BracketRefreshRequested()),
          child: const Text('Reintentar'),
        ),
      ),
    );
  }
}

/// El cuadro: una columna por ronda; cada llave queda a la altura de las
/// dos que la alimentan y se une a ellas solo si hay evidencia
/// (`BracketSlot.linkedToNext`).
class _BracketCanvas extends StatelessWidget {
  const _BracketCanvas({
    required this.rounds,
    required this.availableWidth,
    this.explainUndecided = false,
  });

  final List<BracketRoundView> rounds;
  final double availableWidth;
  final bool explainUndecided;

  static const _gap = 28.0;
  static const _minColumnWidth = 208.0;
  static const maxColumnWidth = 264.0;

  /// Lugar de una llave: dos renglones de equipo y uno de estado, con el
  /// texto agrandado. Android agranda cada tamaño de letra por separado
  /// (escala no lineal: las letras chicas crecen más), así que los
  /// renglones se suman con su propio tamaño.
  static double slotHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final text = Theme.of(context).textTheme;
    double line(TextStyle? style) =>
        scaler.scale(style?.fontSize ?? 14) * (style?.height ?? 1.5);
    final content = 2 * line(text.bodyMedium) + line(text.labelSmall);
    // Relleno y separaciones de la tarjeta (22) y margen del lugar (8).
    return math.max(scaler.scale(60) + 44, content + 30 + 4);
  }

  /// Alto de la tarjeta de una llave.
  static double cardHeight(BuildContext context) => slotHeight(context) - 8;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final columnWidth =
        ((availableWidth - _gap * (rounds.length - 1)) / rounds.length).clamp(
          _minColumnWidth,
          maxColumnWidth,
        );
    final slotHeight = _BracketCanvas.slotHeight(context);
    final title = Theme.of(context).textTheme.titleSmall;
    final headerHeight =
        scaler.scale(title?.fontSize ?? 14) * (title?.height ?? 1.5) + 12;
    final height = rounds.first.slots.length * slotHeight;
    final theme = Theme.of(context);

    return CustomPaint(
      painter: _ConnectorPainter(
        rounds: rounds,
        columnWidth: columnWidth,
        gap: _gap,
        top: headerHeight,
        height: height,
        color: theme.colorScheme.outline,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (j, round) in rounds.indexed) ...[
            if (j > 0) const SizedBox(width: _gap),
            SizedBox(
              width: columnWidth,
              child: Column(
                children: [
                  SizedBox(
                    height: headerHeight,
                    child: Semantics(
                      header: true,
                      child: Text(
                        round.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ),
                  for (final slot in round.slots)
                    SizedBox(
                      height: height / round.slots.length,
                      child: Center(
                        child: SizedBox(
                          height: cardHeight(context),
                          child: _TieCard(
                            slot: slot,
                            round: round.label,
                            explainUndecided: explainUndecided,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.rounds,
    required this.columnWidth,
    required this.gap,
    required this.top,
    required this.height,
    required this.color,
  });

  final List<BracketRoundView> rounds;
  final double columnWidth;
  final double gap;
  final double top;
  final double height;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var j = 0; j < rounds.length - 1; j++) {
      final slots = rounds[j].slots;
      final cell = height / slots.length;
      final parentCell = height / rounds[j + 1].slots.length;
      final x1 = j * (columnWidth + gap) + columnWidth;
      final xm = x1 + gap / 2;
      final x2 = x1 + gap;
      for (final (i, slot) in slots.indexed) {
        if (!slot.linkedToNext) continue;
        final y1 = top + cell * (i + 0.5);
        final y2 = top + parentCell * (i ~/ 2 + 0.5);
        canvas.drawPath(
          Path()
            ..moveTo(x1, y1)
            ..lineTo(xm, y1)
            ..lineTo(xm, y2)
            ..lineTo(x2, y2),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.rounds != rounds ||
      old.columnWidth != columnWidth ||
      old.top != top ||
      old.height != height ||
      old.color != color;
}

/// Una llave: los dos equipos con sus goles (y la tanda), el ganador
/// marcado, y el estado o el horario. En una serie, los goles son el
/// global (lo jugado) y el renglón de estado dice cada pierna. Tocarla abre
/// el partido (en una serie, la pierna en curso o la última).
class _TieCard extends StatelessWidget {
  const _TieCard({
    required this.slot,
    required this.round,
    this.explainUndecided = false,
  });

  final BracketSlot slot;
  final String round;

  /// Una llave terminada sin evidencia de quién avanzó lo dice («Sin dato
  /// de la definición»): copas internacionales.
  final bool explainUndecided;

  static const _undecided = 'Sin dato de la definición';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tie = slot.tie;
    if (tie == null) {
      final teams = slot.qualified;
      return Semantics(
        label: [
          round,
          teams.isEmpty
              ? 'A definir'
              : '${teams.map((t) => t.name).join(' contra ')}, partido '
                    'sin datos',
        ].join('. '),
        excludeSemantics: true,
        child: Card(
          margin: EdgeInsets.zero,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 2; i++)
                  _PlaceholderLine(team: teams.elementAtOrNull(i)),
                const SizedBox(height: 4),
                Text(
                  'Sin datos del partido',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final outcome = slot.outcome;
    final winner = outcome?.winner.id;
    final now = context.read<Clock>().now();
    final undecided = explainUndecided && outcome == null && tie.isComplete;
    final goals = tie.isSeries
        ? tie.partialAggregate
        : tie.scoreOf(tie.decisive);
    final penalties = tie.decisive.status.isFinished ? tie.penalties : null;
    final (info, inPlay) = tie.isSeries
        ? _seriesInfo(tie, now, undecided: undecided)
        : _singleInfo(tie.decisive, now, undecided: undecided);

    return Semantics(
      button: true,
      label: [
        round,
        if (tie.isSeries) ...[
          '${tie.first.name} contra ${tie.second.name}, ida y vuelta',
          for (final (i, leg) in tie.legs.indexed)
            '${MatchLabels.leg(i)}: ${MatchLabels.semantics(leg)}',
          ?MatchLabels.aggregate(tie),
        ] else
          MatchLabels.semantics(tie.decisive),
        if (outcome != null) MatchLabels.tieAdvances(outcome, tie),
        if (undecided) _undecided,
      ].join('. '),
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.matchDetail(tie.current.id)),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TeamLine(
                  team: tie.first,
                  goals: goals?.home,
                  penalties: penalties?.home,
                  isWinner: winner == tie.first.id,
                  isLoser: winner != null && winner != tie.first.id,
                ),
                const SizedBox(height: 2),
                _TeamLine(
                  team: tie.second,
                  goals: goals?.away,
                  penalties: penalties?.away,
                  isWinner: winner == tie.second.id,
                  isLoser: winner != null && winner != tie.second.id,
                ),
                const SizedBox(height: 4),
                Text(
                  info,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: inPlay ? theme.colorScheme.error : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Horario si no empezó; si no, el estado.
  static (String, bool) _singleInfo(
    Match m,
    DateTime now, {
    required bool undecided,
  }) {
    if (m.status.isScheduled && !m.isResultOverdue(now)) {
      final day = m.kickoff.argentinaDay;
      return (
        [
          if (day != null) ArgentinaTime.formatDay(day),
          MatchLabels.kickoffTime(m.kickoff),
        ].join(' · '),
        false,
      );
    }
    final status = MatchLabels.status(m.status) ?? '';
    return (undecided ? '$status · $_undecided' : status, m.status.isInPlay);
  }

  /// Cada pierna jugada en el orden de la llave («Ida 1-0 · Vuelta 0-2»),
  /// la que está en juego, o el horario de la próxima.
  static (String, bool) _seriesInfo(
    KnockoutTie tie,
    DateTime now, {
    required bool undecided,
  }) {
    if (undecided) return (_undecided, false);
    for (final (i, leg) in tie.legs.indexed) {
      if (leg.status.isInPlay) return ('${MatchLabels.leg(i)} en juego', true);
      if (leg.status.isFinished) continue;
      final (schedule, _) = _singleInfo(leg, now, undecided: false);
      return ('${MatchLabels.leg(i)}: $schedule', false);
    }
    final played = [
      for (final (i, leg) in tie.legs.indexed)
        if (tie.scoreOf(leg) case final s?)
          '${MatchLabels.leg(i)} ${s.home}-${s.away}',
    ];
    if (tie.legs.length < tie.expectedLegs) {
      played.add('${MatchLabels.leg(tie.legs.length)} sin datos');
    }
    return (played.join(' · '), false);
  }
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({
    required this.team,
    required this.goals,
    required this.penalties,
    required this.isWinner,
    required this.isLoser,
  });

  final TeamRef team;
  final int? goals;
  final int? penalties;
  final bool isWinner;
  final bool isLoser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: isWinner ? FontWeight.bold : null,
      color: isLoser ? theme.colorScheme.onSurfaceVariant : null,
    );
    return Row(
      children: [
        TeamBadge(name: team.name, url: team.badgeUrl, size: 20),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            team.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (isWinner)
          Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
        if (goals != null) ...[
          const SizedBox(width: 4),
          Text('$goals', style: style),
        ],
        if (penalties != null)
          Text(' ($penalties)', style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _PlaceholderLine extends StatelessWidget {
  const _PlaceholderLine({required this.team});

  final TeamRef? team;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = team;
    return Row(
      children: [
        if (t == null)
          Icon(
            Icons.help_outline,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          )
        else
          TeamBadge(name: t.name, url: t.badgeUrl, size: 20),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            t?.name ?? 'A definir',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: t == null ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
        ),
      ],
    );
  }
}
