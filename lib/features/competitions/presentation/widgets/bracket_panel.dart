import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/sync/sync_progress.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/presentation/formatters/sync_texts.dart';
import '../../../../shared/presentation/formatters/match_labels.dart';
import '../../../../shared/presentation/layout/text_measure.dart';
import '../../../../shared/presentation/theme/app_palette.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text.dart';
import '../../../../shared/presentation/widgets/info_banner.dart';
import '../../../../shared/presentation/widgets/match_card.dart';
import '../../../../shared/presentation/widgets/match_group.dart';
import '../../../../shared/presentation/widgets/scroll_row.dart';
import '../../../../shared/presentation/widgets/section_header.dart';
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
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          filters.isEmpty ? AppSpacing.sm : 0,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          if (widget.isRefreshing) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: AppSpacing.sm),
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
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: _ChampionBanner(team: champion),
        ),
      if (shown.any((r) => r.pairingUnknown))
        const Padding(
          padding: EdgeInsets.only(top: AppSpacing.md),
          child: InfoBanner(
            tone: InfoTone.warning,
            icon: Icons.info_outline,
            text:
                'Faltan partidos de la ronda siguiente en TheSportsDB: '
                'algunas llaves van por fecha, sin unir.',
          ),
        ),
      const SizedBox(height: AppSpacing.md),
      // Entra a lo ancho si hay lugar; si no, se desplaza.
      LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _BracketCanvas(
            rounds: shown,
            availableWidth: constraints.maxWidth,
            now: now,
            explainUndecided: continental,
          ),
        ),
      ),
      for (final round in bracket.preliminary)
        if (round.hasMatches) ...[
          SectionHeader(
            title: round.label,
            subtitle: 'Sus ganadores juegan los octavos de final.',
          ),
          _TieList(round: round, now: now, explainUndecided: continental),
        ],
      if (bracket.unplaced.isNotEmpty) ...[
        const SectionHeader(title: 'Sin ubicar en el cuadro'),
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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.xs,
          0,
        ),
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

/// El campeón: una fila compacta sobre la superficie de grupo (trofeo,
/// escudo y nombre).
class _ChampionBanner extends StatelessWidget {
  const _ChampionBanner({required this.team});

  final TeamRef team;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Campeón: ${team.name}',
      excludeSemantics: true,
      child: Material(
        color: AppPalette.of(context).group,
        borderRadius: AppRadius.groupAll,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(
                Icons.emoji_events_outlined,
                color: AppPalette.of(context).success,
              ),
              const SizedBox(width: AppSpacing.md),
              TeamBadge(name: team.name, url: team.badgeUrl),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Campeón: ${team.name}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
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
    if (progress.isRunning) {
      final rounds = SyncTexts.running(progress, unit: 'rondas');
      return Semantics(
        liveRegion: true,
        label: rounds,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: progress.total == 0
                    ? null
                    : progress.done / progress.total,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(rounds, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      );
    }
    if (failure == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: InfoBanner(
        tone: InfoTone.offline,
        icon: Icons.cloud_off,
        text: SyncTexts.stopped(progress, failure, unit: 'rondas'),
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
///
/// Las tarjetas se miden con la escala de texto: la columna no baja de la
/// palabra más ancha de los nombres y el lugar de cada llave tiene el alto
/// de la más alta (así los conectores quedan alineados); cada tarjeta va
/// centrada en su lugar, con el alto de su contenido. Con texto grande el
/// cuadro se agranda y se desplaza; nunca recorta los datos de una llave.
class _BracketCanvas extends StatelessWidget {
  const _BracketCanvas({
    required this.rounds,
    required this.availableWidth,
    required this.now,
    this.explainUndecided = false,
  });

  final List<BracketRoundView> rounds;
  final double availableWidth;
  final DateTime now;
  final bool explainUndecided;

  /// Entre columnas: el lugar de los conectores.
  static const _gap = AppSpacing.xl;
  static const _minColumnWidth = 208.0;
  static const maxColumnWidth = 264.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = _CardStyles.of(context);
    final contents = [
      for (final round in rounds)
        [
          for (final slot in round.slots)
            _TieContent.of(slot, now, explainUndecided: explainUndecided),
        ],
    ];
    final all = contents.expand((c) => c).toList();
    final minWidth = math.max(_minColumnWidth, styles.minWidth(all));
    final columnWidth =
        ((availableWidth - _gap * (rounds.length - 1)) / rounds.length)
            .clamp(minWidth, math.max(maxColumnWidth, minWidth))
            .toDouble();
    final cardHeight = styles.cardHeight(all, columnWidth);
    final slotHeight = cardHeight + AppSpacing.sm;
    final headerStyle = theme.textTheme.groupTitle.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final headerHeight =
        rounds
            .map(
              (r) => styles.measure.height(r.label, headerStyle, columnWidth),
            )
            .fold(0.0, math.max) +
        AppSpacing.md;
    final height = rounds.first.slots.length * slotHeight;

    return CustomPaint(
      painter: _ConnectorPainter(
        rounds: rounds,
        columnWidth: columnWidth,
        gap: _gap,
        top: headerHeight,
        height: height,
        definedColor: theme.colorScheme.onSurfaceVariant,
        pendingColor: theme.colorScheme.outline,
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
                        textAlign: TextAlign.center,
                        style: headerStyle,
                      ),
                    ),
                  ),
                  // El lugar de cada llave sale de la más alta del cuadro
                  // (conectores alineados); la tarjeta tiene el alto de su
                  // contenido, centrada en su lugar: las de nombres cortos
                  // no quedan con aire (E7).
                  for (final (i, slot) in round.slots.indexed)
                    SizedBox(
                      height: height / round.slots.length,
                      child: Center(
                        child: _TieCard(
                          slot: slot,
                          content: contents[j][i],
                          round: round.label,
                          styles: styles,
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

/// Llaves fuera del cuadro (Playoffs de la Sudamericana), una al lado de la
/// otra si entran.
class _TieList extends StatelessWidget {
  const _TieList({
    required this.round,
    required this.now,
    required this.explainUndecided,
  });

  final BracketRoundView round;
  final DateTime now;
  final bool explainUndecided;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final styles = _CardStyles.of(context);
        final contents = [
          for (final slot in round.slots)
            _TieContent.of(slot, now, explainUndecided: explainUndecided),
        ];
        final width = math.max(
          styles.minWidth(contents),
          math.min(constraints.maxWidth, _BracketCanvas.maxColumnWidth),
        );
        final height = styles.cardHeight(contents, width);
        final list = Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (i, slot) in round.slots.indexed)
              SizedBox(
                width: width,
                height: height,
                child: _TieCard(
                  slot: slot,
                  content: contents[i],
                  round: round.label,
                  styles: styles,
                ),
              ),
          ],
        );
        if (width <= constraints.maxWidth) return list;
        // Con texto muy grande una tarjeta no entra a lo ancho: se desplaza
        // como el cuadro, sin partir los nombres.
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: width, child: list),
        );
      },
    );
  }
}

/// Conectores entre rondas. Un cruce **definido** (se sabe quién avanzó)
/// va con una línea llena y más gruesa; uno **pendiente**, punteado: la
/// diferencia no depende solo del color. El primer codo es redondeado.
class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.rounds,
    required this.columnWidth,
    required this.gap,
    required this.top,
    required this.height,
    required this.definedColor,
    required this.pendingColor,
  });

  final List<BracketRoundView> rounds;
  final double columnWidth;
  final double gap;
  final double top;
  final double height;
  final Color definedColor;
  final Color pendingColor;

  @override
  void paint(Canvas canvas, Size size) {
    final defined = Paint()
      ..color = definedColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSizes.connectorDefined;
    final pending = Paint()
      ..color = pendingColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSizes.connectorPending;
    void draw(Path path, {required bool isDefined}) {
      if (isDefined) {
        canvas.drawPath(path, defined);
        return;
      }
      const dash = AppSizes.connectorDash;
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 2 * dash) {
          canvas.drawPath(
            metric.extractPath(d, math.min(d + dash, metric.length)),
            pending,
          );
        }
      }
    }

    for (var j = 0; j < rounds.length - 1; j++) {
      final slots = rounds[j].slots;
      final cell = height / slots.length;
      final parentCell = height / rounds[j + 1].slots.length;
      final x1 = j * (columnWidth + gap) + columnWidth;
      final xm = x1 + gap / 2;
      final x2 = x1 + gap;
      // Llave de la ronda siguiente → si todas las que llegan a ella están
      // definidas (el tramo final es compartido).
      final into = <int, bool>{};
      for (final (i, slot) in slots.indexed) {
        if (!slot.linkedToNext) continue;
        final isDefined = slot.outcome != null;
        final y1 = top + cell * (i + 0.5);
        final y2 = top + parentCell * (i ~/ 2 + 0.5);
        final path = Path()..moveTo(x1, y1);
        final dy = y2 - y1;
        if (dy.abs() < 1) {
          path.lineTo(xm, y1);
        } else {
          final r = math.min(AppRadius.connector, dy.abs() / 2);
          path
            ..lineTo(xm - r, y1)
            ..quadraticBezierTo(xm, y1, xm, y1 + r * dy.sign)
            ..lineTo(xm, y2);
        }
        draw(path, isDefined: isDefined);
        into[i ~/ 2] = (into[i ~/ 2] ?? true) && isDefined;
      }
      for (final MapEntry(key: parent, value: isDefined) in into.entries) {
        final y2 = top + parentCell * (parent + 0.5);
        draw(
          Path()
            ..moveTo(xm, y2)
            ..lineTo(x2, y2),
          isDefined: isDefined,
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
      old.definedColor != definedColor ||
      old.pendingColor != pendingColor;
}

enum _InfoTone { normal, live, undecided }

/// Un renglón de equipo de una tarjeta.
final class _LineContent {
  const _LineContent({
    required this.team,
    this.goals,
    this.penalties,
    this.isWinner = false,
    this.isLoser = false,
  });

  /// `null`: «A definir».
  final TeamRef? team;
  final int? goals;
  final int? penalties;
  final bool isWinner;
  final bool isLoser;

  String get label => team?.name ?? 'A definir';
}

/// Lo que muestra la tarjeta de una llave: sirve para dibujarla y para
/// medirla. En una serie, los goles son el global (lo jugado) y el renglón
/// de estado dice cada pierna.
final class _TieContent {
  const _TieContent({
    required this.lines,
    required this.info,
    this.tone = _InfoTone.normal,
    this.hasTie = true,
    this.hasGoals = false,
    this.hasPenalties = false,
  });

  factory _TieContent.of(
    BracketSlot slot,
    DateTime now, {
    required bool explainUndecided,
  }) {
    final tie = slot.tie;
    if (tie == null) {
      final teams = slot.qualified;
      return _TieContent(
        lines: [
          for (var i = 0; i < 2; i++)
            _LineContent(team: teams.elementAtOrNull(i)),
        ],
        info: 'Sin datos del partido',
        hasTie: false,
      );
    }

    final winner = slot.outcome?.winner.id;
    final undecided =
        explainUndecided && slot.outcome == null && tie.isComplete;
    final goals = tie.isSeries
        ? tie.partialAggregate
        : tie.scoreOf(tie.decisive);
    final penalties = tie.decisive.status.isFinished ? tie.penalties : null;
    final (info, inPlay) = tie.isSeries
        ? _seriesInfo(tie, now, undecided: undecided)
        : _singleInfo(tie.decisive, now, undecided: undecided);
    _LineContent line(TeamRef team, int? goals, int? penalties) => _LineContent(
      team: team,
      goals: goals,
      penalties: penalties,
      isWinner: winner == team.id,
      isLoser: winner != null && winner != team.id,
    );
    return _TieContent(
      lines: [
        line(tie.first, goals?.home, penalties?.home),
        line(tie.second, goals?.away, penalties?.away),
      ],
      info: info,
      tone: undecided
          ? _InfoTone.undecided
          : inPlay
          ? _InfoTone.live
          : _InfoTone.normal,
      hasGoals: goals != null,
      hasPenalties: penalties != null,
    );
  }

  static const undecidedText = 'Sin dato de la definición';

  /// Partes que no se separan en dos renglones («Ida 1-0»).
  static String _keep(String text) => text.replaceAll(' ', '\u00A0');

  final List<_LineContent> lines;
  final String info;
  final _InfoTone tone;

  /// `false`: el partido no está en TheSportsDB (lugar «A definir»).
  final bool hasTie;
  final bool hasGoals;
  final bool hasPenalties;

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
    return (undecided ? '$status · $undecidedText' : status, m.status.isInPlay);
  }

  /// Cada pierna jugada en el orden de la llave («Ida 1-0 · Vuelta 0-2»),
  /// la que está en juego, o el horario de la próxima. Con texto grande se
  /// parte entre piernas, nunca dentro de una.
  static (String, bool) _seriesInfo(
    KnockoutTie tie,
    DateTime now, {
    required bool undecided,
  }) {
    if (undecided) return (undecidedText, false);
    for (final (i, leg) in tie.legs.indexed) {
      if (leg.status.isInPlay) return ('${MatchLabels.leg(i)} en juego', true);
      if (leg.status.isFinished) continue;
      final (schedule, _) = _singleInfo(leg, now, undecided: false);
      return ('${MatchLabels.leg(i)}: $schedule', false);
    }
    final played = [
      for (final (i, leg) in tie.legs.indexed)
        if (tie.scoreOf(leg) case final s?)
          _keep('${MatchLabels.leg(i)} ${s.home}-${s.away}'),
    ];
    if (tie.legs.length < tie.expectedLegs) {
      played.add(_keep('${MatchLabels.leg(tie.legs.length)} sin datos'));
    }
    return (played.join(' · '), false);
  }
}

/// Estilos y medidas de las tarjetas con la escala de texto.
final class _CardStyles {
  _CardStyles.of(BuildContext context)
    : measure = TextMeasure.of(context),
      name = Theme.of(context).textTheme.teamName.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      winner = Theme.of(context).textTheme.teamNameWinner.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      info = Theme.of(context).textTheme.statusLabel.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      icon = MediaQuery.textScalerOf(context).scale(AppSizes.statusIcon) {
    goals = measure.width('00', winner);
    penalties = measure.width('(00)', info);
  }

  final TextMeasure measure;

  /// Nombre (y goles) de un equipo; el que avanza, en negrita.
  final TextStyle name;
  final TextStyle winner;

  /// Renglón de estado, horario o piernas; también la tanda.
  final TextStyle info;

  /// ✓ del que avanza e ícono de «Sin dato de la definición».
  final double icon;
  late final double goals;
  late final double penalties;

  static const _padding = AppSpacing.sm + AppSizes.divider;

  /// El nombre de un equipo y, si avanza, el ✓ en el mismo texto, como
  /// carácter de la fuente de íconos: el espacio duro lo une a la última
  /// palabra. (Con un `WidgetSpan`, el motor de texto puede dejarlo solo en
  /// un renglón.) Sirve para dibujar y para medir.
  static TextSpan nameSpan(
    String name,
    TextStyle style, {
    bool check = false,
    Color? checkColor,
  }) => TextSpan(
    text: name,
    style: style,
    children: [
      if (check) ...[
        const TextSpan(text: '\u00A0'),
        TextSpan(
          text: String.fromCharCode(Icons.check.codePoint),
          style: TextStyle(
            fontFamily: Icons.check.fontFamily,
            package: Icons.check.fontPackage,
            fontSize: AppSizes.statusIcon,
            fontWeight: FontWeight.w400,
            color: checkColor,
          ),
        ),
      ],
    ],
  );

  /// Lo que ocupa a la derecha del nombre: goles y tanda, alineados en
  /// columnas dentro de la tarjeta.
  double trailing(_TieContent c) =>
      (c.hasGoals ? AppSpacing.xs + goals : 0) +
      (c.hasPenalties ? AppSpacing.xs + penalties : 0);

  /// Ancho de la tarjeta menos el nombre.
  double _fixed(_TieContent c) =>
      2 * _padding + AppSizes.badgeBracket + AppSpacing.sm + trailing(c);

  /// Ancho mínimo para que ningún nombre se parta a mitad de palabra (el ✓
  /// va pegado a la última palabra del que avanza).
  double minWidth(Iterable<_TieContent> contents) =>
      contents.fold(0, (width, c) {
        var word = 0.0;
        for (final l in c.lines) {
          final style = l.isWinner ? winner : name;
          word = math.max(word, measure.widestWord([l.label], style));
          if (l.isWinner) {
            final last = l.label.split(' ').last;
            word = math.max(
              word,
              measure.spanSize(nameSpan(last, style, check: true)).width,
            );
          }
        }
        return math.max(width, _fixed(c) + word);
      });

  /// Alto de la tarjeta más alta de [contents] con ancho [width].
  double cardHeight(Iterable<_TieContent> contents, double width) =>
      contents.fold(0, (height, c) => math.max(height, _height(c, width)));

  double _height(_TieContent c, double width) {
    final nameWidth = width - _fixed(c);
    double line(_LineContent l) => math.max(
      AppSizes.badgeBracket,
      measure
          .spanSize(
            nameSpan(l.label, l.isWinner ? winner : name, check: l.isWinner),
            maxWidth: nameWidth,
            maxLines: _TeamLine.maxLines,
          )
          .height,
    );
    final infoWidth =
        width -
        2 * _padding -
        (c.tone == _InfoTone.undecided ? icon + AppSpacing.xs : 0);
    return 2 * _padding +
        line(c.lines[0]) +
        AppSpacing.xs +
        line(c.lines[1]) +
        AppSpacing.xs +
        measure.height(c.info, info, infoWidth);
  }
}

/// Una llave: los dos equipos con sus goles (y la tanda), el que avanza
/// en negrita con ✓, y el estado o el horario. Tocarla abre el partido (en
/// una serie, la pierna en curso o la última). Sin partido en TheSportsDB,
/// un lugar «A definir» en gris.
class _TieCard extends StatelessWidget {
  const _TieCard({
    required this.slot,
    required this.content,
    required this.round,
    required this.styles,
  });

  final BracketSlot slot;
  final _TieContent content;
  final String round;
  final _CardStyles styles;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tie = slot.tie;
    final body = Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TeamLine(line: content.lines[0], content: content, styles: styles),
          const SizedBox(height: AppSpacing.xs),
          _TeamLine(line: content.lines[1], content: content, styles: styles),
          const SizedBox(height: AppSpacing.xs),
          _InfoLine(content: content, styles: styles),
        ],
      ),
    );
    final card = Material(
      color: tie == null
          ? colors.surfaceContainerHigh
          : AppPalette.of(context).group,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.groupAll,
        side: BorderSide(color: colors.outlineVariant, width: AppSizes.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: tie == null
          ? body
          : InkWell(
              onTap: () => context.push(AppRoutes.matchDetail(tie.current.id)),
              child: body,
            ),
    );

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
        child: card,
      );
    }
    final outcome = slot.outcome;
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
        if (content.tone == _InfoTone.undecided) _TieContent.undecidedText,
      ].join('. '),
      excludeSemantics: true,
      child: card,
    );
  }
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({
    required this.line,
    required this.content,
    required this.styles,
  });

  /// Un nombre largo va en dos renglones (completo en la semántica y en el
  /// detalle), como en las filas de partido.
  static const maxLines = 2;

  final _LineContent line;
  final _TieContent content;
  final _CardStyles styles;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final team = line.team;
    final color = team == null || line.isLoser
        ? colors.onSurfaceVariant
        : colors.onSurface;
    final style = (line.isWinner ? styles.winner : styles.name).copyWith(
      color: color,
    );
    return Row(
      children: [
        if (team == null)
          Icon(
            Icons.help_outline,
            size: AppSizes.badgeBracket,
            color: colors.onSurfaceVariant,
          )
        else
          TeamBadge(
            name: team.name,
            url: team.badgeUrl,
            size: AppSizes.badgeBracket,
          ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text.rich(
            _CardStyles.nameSpan(
              line.label,
              style,
              check: line.isWinner,
              checkColor: AppPalette.of(context).success,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (content.hasTie) ...[
          if (content.hasGoals) ...[
            const SizedBox(width: AppSpacing.xs),
            SizedBox(
              width: styles.goals,
              child: Text(
                '${line.goals ?? ''}',
                textAlign: TextAlign.end,
                style: style,
              ),
            ),
          ],
          if (content.hasPenalties) ...[
            const SizedBox(width: AppSpacing.xs),
            SizedBox(
              width: styles.penalties,
              child: Text(
                line.penalties == null ? '' : '(${line.penalties})',
                style: styles.info.copyWith(
                  fontWeight: FontWeight.w400,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// Estado, horario o piernas. En juego, en el color de «en vivo» y en
/// negrita; sin dato de la definición, con un ícono de ayuda.
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.content, required this.styles});

  final _TieContent content;
  final _CardStyles styles;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = switch (content.tone) {
      _InfoTone.live => styles.info.copyWith(
        color: AppPalette.of(context).live,
        fontWeight: FontWeight.w700,
      ),
      _ => styles.info.copyWith(color: colors.onSurfaceVariant),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (content.tone == _InfoTone.undecided) ...[
          Icon(
            Icons.help_outline,
            size: styles.icon,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Expanded(child: Text(content.info, style: style)),
      ],
    );
  }
}
