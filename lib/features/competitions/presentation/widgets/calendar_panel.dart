import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../../core/time/calendar_day.dart';
import '../../../../core/time/calendar_month.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/presentation/formatters/failure_messages.dart';
import '../../../../shared/presentation/formatters/match_labels.dart';
import '../../../../shared/presentation/layout/breakpoints.dart';
import '../../../../shared/presentation/widgets/info_banner.dart';
import '../../../../shared/presentation/widgets/match_day_list.dart';
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
        const SizedBox(height: 8),
      ],
      _CoverageStatus(view: view),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
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
      if (undated.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
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
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
          child: Text(
            'No hay partidos guardados en '
            '${MatchLabels.month(month).toLowerCase()}.',
            textAlign: TextAlign.center,
          ),
        )
      else
        ...matchDayItems(
          matches: dayMatches,
          now: now,
          subtitle: (m) => switch (view.labels[m.id]) {
            final label? => [?label.phase, label.stage].join(' · '),
            null => null,
          },
          onTap: (m) => context.push(AppRoutes.matchDetail(m.id)),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          'Partidos guardados en este dispositivo · Horarios de Argentina',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    ];

    const padding = EdgeInsets.fromLTRB(8, 8, 8, 24);
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: Breakpoints.isExpanded(context)
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 480,
                  child: ListView(padding: padding, children: overview),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    children: matches,
                  ),
                ),
              ],
            )
          : ListView(padding: padding, children: [...overview, ...matches]),
    );
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
      final rounds = 'Fechas consultadas ${progress.done} de ${progress.total}';
      return Semantics(
        liveRegion: true,
        label: rounds,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
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
    final upToDate = view.roundsTotal - view.roundsPending;
    if (progress.failure case final failure?) {
      final (:title, message: _) = failureMessage(failure);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InfoBanner(
          tone: InfoTone.offline,
          icon: Icons.cloud_off,
          text:
              'No se pudieron consultar todas las fechas ($upToDate de '
              '${view.roundsTotal} al día). $title',
          action: TextButton(
            onPressed: complete,
            child: const Text('Reintentar'),
          ),
        ),
      );
    }
    if (view.roundsPending == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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

/// «‹ Octubre 2026 ›».
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month, this.onPrevious, this.onNext});

  final CalendarMonth month;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Mes anterior',
        onPressed: onPrevious,
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            MatchLabels.month(month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
      IconButton(
        tooltip: 'Mes siguiente',
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
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

  static const _cellHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              for (final initial in MatchLabels.weekdayInitials)
                Expanded(
                  child: Center(
                    child: Text(
                      initial,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (final week in calendar.month.weeks)
          Row(
            children: [
              for (final day in week)
                Expanded(
                  child: day == null
                      ? const SizedBox(height: _cellHeight)
                      : _DayCell(
                          day: day,
                          count: calendar.matchesOn(day).length,
                          isToday: day == today,
                          isSelected: day == selected,
                          height: _cellHeight,
                          onTap: () => onSelected(day),
                        ),
                ),
            ],
          ),
      ],
    );
  }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasMatches = count > 0;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: isToday
          ? BorderSide(color: colors.primary, width: 1.5)
          : BorderSide.none,
    );
    final matches = switch (count) {
      0 => 'sin partidos guardados',
      1 => '1 partido',
      _ => '$count partidos',
    };

    return Semantics(
      button: hasMatches,
      selected: isSelected,
      excludeSemantics: true,
      label: '${MatchLabels.day(day)}${isToday ? ', hoy' : ''}: $matches',
      child: Material(
        color: isSelected ? colors.primaryContainer : Colors.transparent,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: hasMatches ? onTap : null,
          child: SizedBox(
            height: height,
            child: Center(
              // Con texto grande se achica en vez de desbordar.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${day.day}',
                      style: hasMatches
                          ? theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? colors.onPrimaryContainer
                                  : null,
                            )
                          : theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                    ),
                    const SizedBox(height: 2),
                    if (hasMatches)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.primary
                              : colors.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          child: Text(
                            '$count',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isSelected
                                  ? colors.onPrimary
                                  : colors.onSecondaryContainer,
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: theme.textTheme.labelSmall?.fontSize ?? 11,
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
