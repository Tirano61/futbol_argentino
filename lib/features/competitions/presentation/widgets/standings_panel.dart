import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/sync/sync_progress.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../../shared/presentation/formatters/failure_messages.dart';
import '../../../../shared/presentation/layout/breakpoints.dart';
import '../../../../shared/presentation/widgets/info_banner.dart';
import '../../../../shared/presentation/widgets/status_views.dart';
import '../../../../shared/presentation/widgets/team_badge.dart';
import '../../domain/catalog/competition_catalog.dart';
import '../../domain/standings/standings_table.dart';
import '../../domain/standings/tie_breaker.dart';
import '../../domain/usecases/watch_standings.dart';
import '../bloc/standings_bloc.dart';

/// Vista «Tabla» de una competición: selector de tablas, avance de la
/// descarga, la tabla, su cobertura y las notas del reglamento.
class StandingsPanel extends StatelessWidget {
  const StandingsPanel({
    super.key,
    required this.tableKey,
    required this.onTableSelected,
    required this.onRefresh,
  });

  /// Tabla elegida (`null` o si no existe: la primera).
  final String? tableKey;
  final ValueChanged<String> onTableSelected;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StandingsBloc, StandingsState>(
      builder: (context, state) => switch (state) {
        StandingsInitial() || StandingsLoading() => Center(
          child: Semantics(
            label: 'Cargando tablas',
            child: const CircularProgressIndicator(),
          ),
        ),
        StandingsFailure(:final failure) => ErrorView(
          failure: failure,
          onRetry: () => context.read<StandingsBloc>().add(
            const StandingsRefreshRequested(),
          ),
        ),
        StandingsUnavailable(:final view) => _Unavailable(view: view),
        // Sin tabla anual y con todas las zonas (o grupos) sin verificar.
        StandingsLoaded(:final view) when view.tables.isEmpty => EmptyView(
          icon: Icons.warning_amber,
          title: view.zoneNoun == 'grupo'
              ? 'Grupos no verificados'
              : 'Zonas no verificadas',
          message:
              'Los partidos no coinciden con ${_zonesOf(view)} del '
              'reglamento: la tabla no se muestra. '
              '${view.zoneIssues.firstOrNull ?? ''}',
        ),
        StandingsLoaded(:final view, :final isRefreshing) => _LoadedView(
          view: view,
          isRefreshing: isRefreshing,
          table:
              (tableKey == null ? null : view.table(tableKey!)) ??
              view.tables.first,
          onTableSelected: onTableSelected,
          onRefresh: onRefresh,
        ),
      },
    );
  }
}

String _zonesOf(StandingsView view) =>
    view.zoneNoun == 'grupo' ? 'los grupos' : 'las zonas';

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.view});

  final StandingsView view;

  @override
  Widget build(BuildContext context) {
    final definition = CompetitionCatalog.byId(view.competitionId);
    final name = definition?.name ?? 'esta competición';
    return EmptyView(
      icon: Icons.leaderboard_outlined,
      title: 'Sin tabla',
      message: switch (definition?.rules) {
        KnockoutCupRules() =>
          'La $name se juega por eliminación directa: no tiene tabla de '
              'posiciones.',
        ContinentalCupRules() =>
          'Todavía no hay grupos verificados con el reglamento de la $name '
              '${view.season.apiValue}.',
        _ =>
          'Todavía no hay una tabla verificada con el reglamento de '
              '$name ${view.season.apiValue}.',
      },
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.view,
    required this.isRefreshing,
    required this.table,
    required this.onTableSelected,
    required this.onRefresh,
  });

  final StandingsView view;
  final bool isRefreshing;
  final StandingsTable table;
  final ValueChanged<String> onTableSelected;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          if (isRefreshing) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in view.tables)
                ChoiceChip(
                  label: Text(t.shortTitle),
                  selected: t.key == table.key,
                  onSelected: (_) => onTableSelected(t.key),
                ),
            ],
          ),
          if (view.zoneIssues.isNotEmpty) ...[
            const SizedBox(height: 8),
            InfoBanner(
              tone: InfoTone.warning,
              icon: Icons.warning_amber,
              text: view.zoneNoun == 'grupo'
                  ? 'Grupos no verificados: las tablas de esos grupos no se '
                        'muestran. ${view.zoneIssues.first}'
                  : 'Zonas no verificadas: las tablas por zona no se '
                        'muestran. ${view.zoneIssues.first}',
            ),
          ],
          _SyncStatus(progress: view.progress, coverage: table.coverage),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Semantics(
              header: true,
              child: Text(table.title, style: theme.textTheme.titleLarge),
            ),
          ),
          StandingsTableView(table: table),
          const SizedBox(height: 12),
          _CoverageView(coverage: table.coverage),
          const SizedBox(height: 8),
          _NotesView(table: table),
        ],
      ),
    );
  }
}

/// Avance no bloqueante de la descarga, o por qué se detuvo.
class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.progress, required this.coverage});

  final SyncProgress progress;
  final StandingsCoverage coverage;

  @override
  Widget build(BuildContext context) {
    final failure = progress.failure;
    final rounds =
        'Fechas consultadas ${coverage.roundsQueried} de ${coverage.roundsTotal}';
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
                value: coverage.roundsTotal == 0
                    ? null
                    : coverage.roundsQueried / coverage.roundsTotal,
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
            'No se pudieron consultar todas las fechas '
            '(${coverage.roundsQueried} de ${coverage.roundsTotal}). $title',
        action: TextButton(
          onPressed: () => context.read<StandingsBloc>().add(
            const StandingsRefreshRequested(),
          ),
          child: const Text('Reintentar'),
        ),
      ),
    );
  }
}

enum _Column {
  played('PJ', 'partidos jugados'),
  won('PG', 'ganados'),
  drawn('PE', 'empatados'),
  lost('PP', 'perdidos'),
  goalsFor('GF', 'goles a favor'),
  goalsAgainst('GC', 'goles en contra'),
  goalDifference('DG', 'diferencia de gol'),
  points('Pts', 'puntos');

  const _Column(this.short, this.spoken);

  final String short;
  final String spoken;
}

/// La tabla, con más columnas cuanto más ancha es la ventana. Tocar un
/// equipo abre su ficha.
class StandingsTableView extends StatelessWidget {
  const StandingsTableView({super.key, required this.table});

  final StandingsTable table;

  static const _positionWidth = 36.0;
  static const _cellWidth = 40.0;

  static List<_Column> _columns(BuildContext context) {
    if (Breakpoints.isCompact(context)) {
      return const [_Column.played, _Column.goalDifference, _Column.points];
    }
    if (!Breakpoints.isExpanded(context)) {
      return const [
        _Column.played,
        _Column.won,
        _Column.drawn,
        _Column.lost,
        _Column.goalDifference,
        _Column.points,
      ];
    }
    return _Column.values;
  }

  static String _value(StandingsRow row, _Column c) {
    final s = row.stats;
    return switch (c) {
      _Column.played => '${s.played}',
      _Column.won => '${s.won}',
      _Column.drawn => '${s.drawn}',
      _Column.lost => '${s.lost}',
      _Column.goalsFor => '${s.goalsFor}',
      _Column.goalsAgainst => '${s.goalsAgainst}',
      _Column.goalDifference =>
        s.goalDifference > 0 ? '+${s.goalDifference}' : '${s.goalDifference}',
      _Column.points => '${s.points}',
    };
  }

  static Widget _cell(String text, {TextStyle? style}) => SizedBox(
    width: _cellWidth,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, style: style, maxLines: 1),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columns = _columns(context);
    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final bold = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Las filas ya dicen todo con su etiqueta accesible.
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: _positionWidth,
                  child: Text('#', style: headerStyle),
                ),
                Expanded(child: Text('Equipo', style: headerStyle)),
                for (final c in columns) _cell(c.short, style: headerStyle),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        for (final (index, row) in table.rows.indexed)
          Material(
            color: index.isOdd
                ? theme.colorScheme.surfaceContainerLow
                : Colors.transparent,
            child: Semantics(
              button: true,
              excludeSemantics: true,
              label: _spoken(row, columns),
              child: InkWell(
                onTap: () =>
                    context.go(AppRoutes.teamDetail(row.stats.team.id)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: _positionWidth,
                          child: Text(
                            '${row.position}${row.isShared ? '*' : ''}',
                            style: bold,
                          ),
                        ),
                        TeamBadge(
                          name: row.stats.team.name,
                          url: row.stats.team.badgeUrl,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            row.stats.team.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        for (final c in columns)
                          _cell(
                            _value(row, c),
                            style: c == _Column.points ? bold : null,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _spoken(StandingsRow row, List<_Column> columns) {
    final position = row.isShared
        ? 'Posición ${row.position}, compartida'
        : 'Posición ${row.position}';
    final values = [
      for (final c in columns.reversed) '${c.spoken} ${_value(row, c)}',
    ];
    return '$position: ${row.stats.team.name}. ${values.join(', ')}.';
  }
}

class _CoverageView extends StatelessWidget {
  const _CoverageView({required this.coverage});

  final StandingsCoverage coverage;

  static String _reason(UncountedReason r) => switch (r) {
    UncountedReason.notPlayed => 'por jugar',
    UncountedReason.inPlay => 'en juego',
    UncountedReason.postponed => 'postergado',
    UncountedReason.suspended => 'suspendido',
    UncountedReason.cancelled => 'cancelado',
    UncountedReason.noResult => 'terminado sin resultado',
    UncountedReason.undetermined => 'sin torneo determinado (excluido)',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary =
        'Fechas consultadas ${coverage.roundsQueried} de '
        '${coverage.roundsTotal} · ${coverage.counted} de '
        '${coverage.scheduled} partidos sumados';
    final uncounted = coverage.uncounted;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(summary, style: theme.textTheme.bodyMedium),
          ),
          if (uncounted.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Todos los partidos guardados están sumados.',
                style: theme.textTheme.bodySmall,
              ),
            )
          else
            ExpansionTile(
              title: Text('Partidos sin sumar (${uncounted.length})'),
              expandedAlignment: Alignment.centerLeft,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                for (final u in uncounted)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${switch (u.match.kickoff.argentinaDay) {
                        final day? => ArgentinaTime.formatDay(day),
                        null => 'Sin fecha',
                      }} · Fecha ${u.match.apiRound} · ${u.match.home.name} – '
                      '${u.match.away.name} · ${_reason(u.reason)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _NotesView extends StatelessWidget {
  const _NotesView({required this.table});

  final StandingsTable table;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (table.sharedNote case final shared?)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('* $shared', style: style),
            ),
          for (final note in table.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(note, style: style),
            ),
        ],
      ),
    );
  }
}
