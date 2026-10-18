import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/sync/sync_progress.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../../shared/presentation/formatters/failure_messages.dart';
import '../../../../shared/presentation/theme/app_palette.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text.dart';
import '../../../../shared/presentation/widgets/info_banner.dart';
import '../../../../shared/presentation/widgets/scroll_row.dart';
import '../../../../shared/presentation/widgets/status_views.dart';
import '../../../favorites/presentation/bloc/favorites_bloc.dart';
import '../../domain/catalog/competition_catalog.dart';
import '../../domain/standings/standings_table.dart';
import '../../domain/standings/table_builders.dart';
import '../../domain/usecases/watch_standings.dart';
import '../bloc/standings_bloc.dart';
import 'standings_table_view.dart';

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
    // Grupos CONMEBOL: los puestos que siguen en alguna copa, con el dato
    // del catálogo verificado por temporada (E-D10). Ninguna otra tabla
    // lleva marcadores.
    final format = CompetitionCatalog.byId(
      view.competitionId,
    )?.standingsFor(view.season);
    final groupStage = format is GroupStage ? format : null;
    final advancing = StandingsTableView.advancingTeams(
      table.rows,
      groupStage?.advancingPlaces,
    );
    final legend = advancing.isEmpty ? null : groupStage?.qualificationNote;

    // Filtros de la vista (nivel 3 de la cabecera, Hito E): las tablas en
    // una fila fija que se desplaza, con la elegida a la vista.
    final chips = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: ScrollRow(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        visible: view.tables.indexWhere((t) => t.key == table.key),
        children: [
          for (final t in view.tables)
            ChoiceChip(
              label: Text(t.shortTitle),
              selected: t.key == table.key,
              onSelected: (_) => onTableSelected(t.key),
            ),
        ],
      ),
    );
    final list = RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          if (isRefreshing) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (view.zoneIssues.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: Semantics(
              header: true,
              child: Text(
                table.title,
                style: theme.textTheme.sectionTitle.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          _CoverageLine(coverage: table.coverage),
          const SizedBox(height: AppSpacing.sm),
          StandingsTableView(
            table: table,
            favorites: _favoriteIds(context),
            advancing: advancing,
          ),
          if (legend != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.xs,
                0,
              ),
              child: QualificationLegend(note: legend),
            ),
          _UncountedView(coverage: table.coverage),
          // La nota de clasificación ya la dice la leyenda.
          _NotesView(table: table, omit: legend),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chips,
        Expanded(child: list),
      ],
    );
  }
}

/// Favoritos del `FavoritesBloc` global (0 peticiones). El panel solo, sin
/// la app alrededor (tests del panel), no tiene favoritos.
Set<int> _favoriteIds(BuildContext context) {
  try {
    return context.select<FavoritesBloc, Set<int>>(
      (bloc) => {for (final t in bloc.state.teams) t.teamId},
    );
  } on ProviderNotFoundException {
    return const {};
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
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: coverage.roundsTotal == 0
                    ? null
                    : coverage.roundsQueried / coverage.roundsTotal,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(rounds, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      );
    }
    if (failure == null) return const SizedBox.shrink();
    final (:title, message: _) = failureMessage(failure);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
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

/// Una línea debajo del título: si la tabla está completa o es parcial
/// (con texto e ícono, no solo color) y qué datos tiene detrás. Los
/// partidos excluidos por no tener torneo se avisan aparte.
class _CoverageLine extends StatelessWidget {
  const _CoverageLine({required this.coverage});

  final StandingsCoverage coverage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final palette = AppPalette.of(context);
    final summary =
        'Fechas consultadas ${coverage.roundsQueried} de '
        '${coverage.roundsTotal} · ${coverage.counted} de '
        '${coverage.scheduled} partidos sumados';
    final (icon, color, status) = coverage.isComplete
        ? (Icons.check_circle, palette.success, 'Tabla completa')
        : coverage.roundsQueried < coverage.roundsTotal
        ? (Icons.warning_amber, palette.warning, 'Tabla parcial')
        : (Icons.incomplete_circle, colors.onSurfaceVariant, 'Tabla parcial');
    final style = theme.textTheme.secondary.copyWith(
      color: colors.onSurfaceVariant,
    );
    final excluded = coverage.uncounted
        .where((u) => u.reason == UncountedReason.undetermined)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text.rich(
            TextSpan(
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    // Dentro del texto, Flutter ya lo escala con la letra.
                    child: Icon(icon, size: AppSizes.statusIcon, color: color),
                  ),
                ),
                TextSpan(
                  text: status,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: ' · $summary'),
              ],
            ),
            style: style,
          ),
        ),
        if (excluded > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: InfoBanner(
              tone: InfoTone.warning,
              text: excluded == 1
                  ? '1 partido excluido: no se pudo ubicar en un torneo.'
                  : '$excluded partidos excluidos: no se pudieron ubicar en '
                        'un torneo.',
            ),
          ),
      ],
    );
  }
}

/// Los partidos guardados que la tabla no suma, por motivo (desplegable).
class _UncountedView extends StatelessWidget {
  const _UncountedView({required this.coverage});

  final StandingsCoverage coverage;

  static String _reason(UncountedReason r) => switch (r) {
    UncountedReason.notPlayed => 'Por jugar',
    UncountedReason.inPlay => 'En juego',
    UncountedReason.postponed => 'Postergados',
    UncountedReason.suspended => 'Suspendidos',
    UncountedReason.cancelled => 'Cancelados',
    UncountedReason.noResult => 'Terminados sin resultado',
    UncountedReason.undetermined => 'Excluidos: sin torneo determinado',
  };

  @override
  Widget build(BuildContext context) {
    final uncounted = coverage.uncounted;
    if (uncounted.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = theme.textTheme.secondary.copyWith(
      color: colors.onSurfaceVariant,
    );
    final byReason = <UncountedReason, List<UncountedMatch>>{};
    for (final u in uncounted) {
      byReason.putIfAbsent(u.reason, () => []).add(u);
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: ExpansionTile(
        title: Text(
          'Partidos sin sumar (${uncounted.length})',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        dense: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        shape: const Border(),
        collapsedShape: const Border(),
        expandedAlignment: Alignment.centerLeft,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          0,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        children: [
          for (final reason in UncountedReason.values)
            if (byReason[reason] case final matches?) ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.xs,
                ),
                child: Text(
                  '${_reason(reason)} (${matches.length})',
                  style: style.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final u in matches)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    '${switch (u.match.kickoff.argentinaDay) {
                      final day? => ArgentinaTime.formatDay(day),
                      null => 'Sin fecha',
                    }} · Fecha ${u.match.apiRound} · ${u.match.home.name} – '
                    '${u.match.away.name}',
                    style: style,
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

/// Notas al pie, siempre visibles: la posición compartida, el reglamento y
/// que la tabla la calcula la app (no es la oficial).
class _NotesView extends StatelessWidget {
  const _NotesView({required this.table, this.omit});

  final StandingsTable table;

  /// Una nota que ya está a la vista en otro lugar (la leyenda).
  final String? omit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = theme.textTheme.secondary.copyWith(
      color: colors.onSurfaceVariant,
    );
    final iconSize = MediaQuery.textScalerOf(
      context,
    ).scale(AppSizes.statusIcon);
    Widget note(String text, {bool unofficial = false}) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unofficial) ...[
            Icon(Icons.info_outline, size: iconSize, color: colors.primary),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child: Text(
              text,
              style: unofficial
                  ? style.copyWith(color: colors.onSurface)
                  : style,
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          if (table.sharedNote case final shared?) note('* $shared'),
          for (final n in table.notes)
            if (n == StandingsNotes.unofficial)
              note(n, unofficial: true)
            else if (n != omit)
              note(n),
        ],
      ),
    );
  }
}
