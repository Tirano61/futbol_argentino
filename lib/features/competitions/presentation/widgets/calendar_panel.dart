import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../../core/time/calendar_day.dart';
import '../../../../core/time/calendar_month.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/presentation/formatters/sync_texts.dart';
import '../../../../shared/presentation/formatters/match_labels.dart';
import '../../../../shared/presentation/theme/app_palette.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text.dart';
import '../../../../shared/presentation/widgets/info_banner.dart';
import '../../../../shared/presentation/widgets/match_card.dart';
import '../../../../shared/presentation/widgets/match_day_list.dart';
import '../../../../shared/presentation/widgets/match_group.dart';
import '../../../matches/domain/entities/match.dart';
import '../../domain/calendar/month_calendar.dart';
import '../../domain/usecases/watch_competition_calendar.dart';
import '../bloc/calendar_bloc.dart';

/// Vista «Calendario» de una competición: el mes con los días que tienen
/// partidos guardados y los partidos del día elegido (debajo; en
/// escritorio, al costado).
class CalendarPanel extends StatefulWidget {
  const CalendarPanel({
    super.key,
    required this.month,
    required this.onMonthChanged,
    required this.onRefresh,
  });

  /// Mes elegido; `null`: el que corresponde a hoy
  /// ([MonthCalendar.initialMonth]).
  final CalendarMonth? month;
  final ValueChanged<CalendarMonth> onMonthChanged;
  final Future<void> Function() onRefresh;

  @override
  State<CalendarPanel> createState() => _CalendarPanelState();
}

class _CalendarPanelState extends State<CalendarPanel> {
  /// Día elegido; `null` (o de otro mes): el que corresponde
  /// ([MonthCalendar.defaultDay]).
  CalendarDay? _day;

  /// Se eligieron los partidos sin fecha.
  bool _undated = false;

  void _changeMonth(CalendarMonth month) {
    setState(() {
      _day = null;
      _undated = false;
    });
    widget.onMonthChanged(month);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CalendarBloc, CalendarState>(
      builder: (context, state) => switch (state) {
        CalendarInitial() || CalendarLoading() => Center(
          child: Semantics(
            label: 'Cargando calendario',
            child: const CircularProgressIndicator(),
          ),
        ),
        CalendarLoaded(:final view, :final isRefreshing) => _content(
          context,
          view,
          isRefreshing,
        ),
      },
    );
  }

  Widget _content(
    BuildContext context,
    CompetitionCalendar view,
    bool isRefreshing,
  ) {
    final now = context.read<Clock>().now();
    final today = ArgentinaTime.dayOf(now);
    final month =
        widget.month ??
        MonthCalendar.initialMonth(
          view.matches,
          today: today,
          season: view.season,
        );
    final calendar = MonthCalendar.of(month, view.matches);
    final undated = MonthCalendar.undated(view.matches);
    final range = MonthCalendar.navigableRange(view.matches, month);
    final showUndated = _undated && undated.isNotEmpty;
    final day = showUndated
        ? null
        : switch (_day) {
            final day? when month.contains(day) => day,
            _ => calendar.defaultDay(today),
          };

    final overview = <Widget>[
      if (isRefreshing) ...[
        const LinearProgressIndicator(),
        const SizedBox(height: AppSpacing.sm),
      ],
      _CoverageStatus(view: view),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _gridMaxWidth),
          child: Material(
            color: AppPalette.of(context).group,
            borderRadius: AppRadius.groupAll,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.xs,
                AppSpacing.sm,
              ),
              child: Column(
                children: [
                  _MonthHeader(
                    month: month,
                    onPrevious: month.isAfter(range.first)
                        ? () => _changeMonth(month.addMonths(-1))
                        : null,
                    onNext: month.isBefore(range.last)
                        ? () => _changeMonth(month.addMonths(1))
                        : null,
                  ),
                  _MonthGrid(
                    calendar: calendar,
                    today: today,
                    selected: day,
                    onSelected: (day) => setState(() {
                      _day = day;
                      _undated = false;
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      if (undated.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Wrap(
            children: [
              ChoiceChip(
                label: Text(
                  '${MatchLabels.unconfirmedDate} (${undated.length})',
                ),
                selected: showUndated,
                onSelected: (_) => setState(() => _undated = true),
              ),
            ],
          ),
        ),
    ];

    final dayMatches = showUndated
        ? undated
        : day == null
        ? const <Match>[]
        : calendar.matchesOn(day);
    final matches = <Widget>[
      if (dayMatches.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.xs,
            0,
          ),
          child: Text(
            'No hay partidos guardados en '
            '${MatchLabels.month(month).toLowerCase()}.',
            textAlign: TextAlign.center,
          ),
        )
      else ...[
        DayHeader(day: showUndated ? null : day),
        // El contexto (fase · etapa) una vez, en el encabezado del grupo.
        for (final (i, group) in _byStage(dayMatches, view.labels).indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          MatchGroup(
            header: switch (group.label) {
              (phase: final String phase, :final stage) => MatchGroupHeader(
                title: phase,
                detail: stage,
                detailInline: true,
              ),
              (phase: null, :final stage) => MatchGroupHeader(title: stage),
              null => null,
            },
            children: [
              for (final m in group.matches)
                MatchCard(
                  key: ValueKey(m.id),
                  match: m,
                  now: now,
                  onTap: () => context.push(AppRoutes.matchDetail(m.id)),
                ),
            ],
          ),
        ],
      ],
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: Text(
          'Partidos guardados en este dispositivo · Horarios de Argentina',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ];

    const padding = EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.xl,
    );
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      // Con el ancho de la vista (no el de la pantalla) y la escala de
      // texto: dos paneles solo si la lista también entra cómoda.
      child: LayoutBuilder(
        builder: (context, constraints) =>
            splitsAt(constraints.maxWidth, MediaQuery.textScalerOf(context))
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: calendarWidth,
                    child: ListView(padding: padding, children: overview),
                  ),
                  const VerticalDivider(width: AppSizes.divider),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.xl,
                      ),
                      children: matches,
                    ),
                  ),
                ],
              )
            : ListView(padding: padding, children: [...overview, ...matches]),
      ),
    );
  }

  /// Ancho máximo de la grilla del mes.
  static const _gridMaxWidth = 560.0;

  /// Columna del calendario con los dos paneles.
  static const calendarWidth = 480.0;

  /// Desde este ancho disponible se ponen el mes y la lista lado a lado
  /// (§9 de `docs/HITO_E.md`)…
  static const splitMinWidth = 900.0;

  /// …si a la lista le quedan al menos estos píxeles a escala 1 (con texto
  /// grande, más).
  static const listMinWidth = 400.0;

  /// Si en [width] van el mes y la lista lado a lado.
  static bool splitsAt(double width, TextScaler scaler) =>
      width >= splitMinWidth &&
      width - calendarWidth - AppSizes.divider >= scaler.scale(listMinWidth);

  /// Los partidos del día por fase · etapa, en el orden del primero de cada
  /// una (dentro de cada grupo, por hora).
  static List<({CalendarMatchLabel? label, List<Match> matches})> _byStage(
    List<Match> matches,
    Map<int, CalendarMatchLabel> labels,
  ) {
    final groups = <CalendarMatchLabel?, List<Match>>{};
    for (final m in matches) {
      groups.putIfAbsent(labels[m.id], () => []).add(m);
    }
    return [
      for (final MapEntry(:key, :value) in groups.entries)
        (label: key, matches: value),
    ];
  }
}

/// Avance de la descarga, por qué se detuvo, o qué falta consultar.
class _CoverageStatus extends StatelessWidget {
  const _CoverageStatus({required this.view});

  final CompetitionCalendar view;

  @override
  Widget build(BuildContext context) {
    final progress = view.progress;
    void complete() =>
        context.read<CalendarBloc>().add(const CalendarCompletionRequested());

    if (progress.isRunning) {
      final rounds = SyncTexts.running(progress, unit: 'fechas');
      return Semantics(
        liveRegion: true,
        label: rounds,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
    if (progress.failure case final failure?) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: InfoBanner(
          tone: InfoTone.offline,
          icon: Icons.cloud_off,
          text: SyncTexts.stopped(
            progress,
            failure,
            unit: 'fechas',
            stored: view.roundsStored,
          ),
          action: TextButton(
            onPressed: complete,
            child: const Text('Reintentar'),
          ),
        ),
      );
    }
    if (view.roundsPending == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InfoBanner(
        icon: Icons.event_note,
        text: view.roundsStored == 0
            ? 'Todavía no hay fechas guardadas de esta temporada '
                  '(${view.roundsTotal} por consultar).'
            : 'Se muestra lo guardado: faltan consultar o actualizar '
                  '${view.roundsPending} de ${view.roundsTotal} fechas.',
        action: TextButton(onPressed: complete, child: const Text('Completar')),
      ),
    );
  }
}

/// «Octubre 2026» a la izquierda y los dos chevrons juntos a la derecha.
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month, this.onPrevious, this.onNext});

  final CalendarMonth month;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                MatchLabels.month(month),
                style: theme.textTheme.sectionTitle.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Mes anterior',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Mes siguiente',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// Grilla del mes, de lunes a domingo. Solo se pueden elegir los días con
/// partidos.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.calendar,
    required this.today,
    required this.selected,
    required this.onSelected,
  });

  final MonthCalendar calendar;
  final CalendarDay today;
  final CalendarDay? selected;
  final ValueChanged<CalendarDay> onSelected;

  /// Separa las celdas: el anillo de hoy no se pega al día elegido.
  static const _cellGap = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = _DayStyles.of(theme.textTheme);
    final scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle s) => scaler.scale(s.fontSize!) * (s.height ?? 1.5);
    // El alto crece con el texto (nunca menos que el área táctil).
    final height = math.max(
      AppSizes.tapTarget,
      line(styles.number) + line(styles.count) + AppSpacing.sm,
    );
    return Column(
      children: [
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                for (final initial in MatchLabels.weekdayInitials)
                  Expanded(
                    child: Center(
                      child: Text(
                        initial,
                        style: theme.textTheme.tableHeader.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        for (final week in calendar.month.weeks)
          Row(
            children: [
              for (final day in week)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(_cellGap),
                    child: day == null
                        ? SizedBox(height: height)
                        : _DayCell(
                            day: day,
                            count: calendar.matchesOn(day).length,
                            isToday: day == today,
                            isSelected: day == selected,
                            height: height,
                            onTap: () => onSelected(day),
                          ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Número del día (tabular) y cantidad de partidos.
final class _DayStyles {
  const _DayStyles({required this.number, required this.count});

  final TextStyle number;
  final TextStyle count;

  factory _DayStyles.of(TextTheme text) => _DayStyles(
    number: text.tableStat,
    count: text.statusLabel.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.count,
    required this.isToday,
    required this.isSelected,
    required this.height,
    required this.onTap,
  });

  final CalendarDay day;
  final int count;
  final bool isToday;
  final bool isSelected;
  final double height;
  final VoidCallback onTap;

  /// Anillo de hoy (maqueta de E1). Elegido y hoy a la vez: el anillo va
  /// en el color del texto, así sigue a la vista.
  static const _todayRing = 1.5;

  /// Punto delante de la cantidad.
  static const _dot = 5.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final styles = _DayStyles.of(theme.textTheme);
    final hasMatches = count > 0;
    final shape = RoundedRectangleBorder(
      borderRadius: AppRadius.controlAll,
      side: isToday
          ? BorderSide(
              color: isSelected ? colors.onPrimary : colors.primary,
              width: _todayRing,
              strokeAlign: BorderSide.strokeAlignInside,
            )
          : BorderSide.none,
    );
    final matches = switch (count) {
      0 => 'sin partidos guardados',
      1 => '1 partido',
      _ => '$count partidos',
    };
    final countColor = isSelected ? colors.onPrimary : colors.primary;
    final countRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _dot,
          height: _dot,
          decoration: BoxDecoration(color: countColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text('$count', style: styles.count.copyWith(color: countColor)),
      ],
    );

    return Semantics(
      button: hasMatches,
      selected: isSelected,
      excludeSemantics: true,
      label: '${MatchLabels.day(day)}${isToday ? ', hoy' : ''}: $matches',
      child: Material(
        color: isSelected ? colors.primary : Colors.transparent,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: hasMatches ? onTap : null,
          child: SizedBox(
            height: height,
            child: Center(
              // Solo si la celda es más angosta que el número (texto muy
              // grande en un teléfono): se achica en vez de desbordar.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${day.day}',
                      style: hasMatches
                          ? styles.number.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? colors.onPrimary
                                  : colors.onSurface,
                            )
                          : styles.number.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                    ),
                    // Sin partidos: el lugar queda, así los números se
                    // alinean.
                    Visibility(
                      visible: hasMatches,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: countRow,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
