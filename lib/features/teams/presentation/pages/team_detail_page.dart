import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/sync/sync_progress.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/presentation/formatters/failure_messages.dart';
import '../../../../shared/presentation/layout/text_measure.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text.dart';
import '../../../../shared/presentation/widgets/info_banner.dart';
import '../../../../shared/presentation/widgets/live_auto_refresh.dart';
import '../../../../shared/presentation/widgets/match_day_list.dart';
import '../../../../shared/presentation/widgets/refresh_feedback.dart';
import '../../../../shared/presentation/widgets/section_header.dart';
import '../../../../shared/presentation/widgets/status_views.dart';
import '../../../../shared/presentation/widgets/team_badge.dart';
import '../../../competitions/domain/catalog/competition_catalog.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../../../matches/domain/services/match_grouping.dart';
import '../../domain/entities/team_detail.dart';
import '../../domain/repositories/team_repository.dart';
import '../../domain/usecases/watch_team_detail.dart';
import '../bloc/team_detail_bloc.dart';

/// Ficha de un equipo (`/equipos/:teamId`): próximos y disputados de todas
/// las competiciones guardadas. Se ve enseguida con lo guardado y se va
/// completando; al salir, se detiene la descarga.
class TeamDetailPage extends StatelessWidget {
  const TeamDetailPage({super.key, required this.teamId});

  final int teamId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TeamDetailBloc(
        watchTeamDetail: WatchTeamDetail(
          teams: context.read<TeamRepository>(),
          matches: context.read<MatchRepository>(),
        ),
        clock: context.read<Clock>(),
      )..add(TeamDetailStarted(teamId)),
      child: const _TeamDetailView(),
    );
  }
}

class _TeamDetailView extends StatefulWidget {
  const _TeamDetailView();

  @override
  State<_TeamDetailView> createState() => _TeamDetailViewState();
}

class _TeamDetailViewState extends State<_TeamDetailView> {
  /// Se apaga cuando la sección de la ficha queda oculta (otra sección del
  /// menú) y se prende al volver.
  ValueListenable<TickerModeData>? _visible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.getValuesNotifier(context);
    if (visible == _visible) return;
    _visible?.removeListener(_onVisibilityChanged);
    _visible = visible..addListener(_onVisibilityChanged);
  }

  void _onVisibilityChanged() => context.read<TeamDetailBloc>().add(
    _visible!.value.enabled
        ? const TeamDetailResumed()
        : const TeamDetailPaused(),
  );

  @override
  void dispose() {
    _visible?.removeListener(_onVisibilityChanged);
    super.dispose();
  }

  /// Actualiza y, si no hizo falta consultar la red (se actualizó hace
  /// menos de 30 s), lo avisa.
  Future<void> _refresh() async {
    final bloc = context.read<TeamDetailBloc>()
      ..add(const TeamDetailRefreshRequested());
    final after = await bloc.stream.firstWhere((s) => !s.isBusy);
    if (after case TeamDetailLoaded(:final detail)
        when mounted &&
            detail.progress.fetched == 0 &&
            detail.progress.failure == null &&
            detail.infoError == null) {
      showAlreadyUpToDate(context);
    }
  }

  /// Un partido del equipo está en vivo y la ficha no está cargando (D11).
  /// Los de otras competiciones no se cuentan: no tienen rondas guardadas.
  bool _hasLiveMatches() => switch (context.read<TeamDetailBloc>().state) {
    final TeamDetailLoaded state when !state.isBusy => MatchGrouping.anyLive([
      for (final m in [...state.detail.upcoming, ...state.detail.played])
        m.match,
    ], context.read<Clock>().now()),
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeamDetailBloc, TeamDetailState>(
      builder: (context, state) {
        final bloc = context.read<TeamDetailBloc>();
        void refresh() => bloc.add(const TeamDetailRefreshRequested());
        return Scaffold(
          appBar: AppBar(
            title: Text(switch (state) {
              TeamDetailLoaded(:final detail) => detail.team!.name,
              _ => 'Equipo',
            }),
            // El favorito va en la cabecera, junto al nombre (E-D14).
            actions: [
              IconButton(
                tooltip: 'Actualizar',
                onPressed: state.isBusy ? null : _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: LiveAutoRefresh(
            hasLiveMatches: _hasLiveMatches,
            onTick: () => bloc.add(const TeamDetailLiveTick()),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: switch (state) {
                  TeamDetailInitial() || TeamDetailLoading() => Center(
                    child: Semantics(
                      label: 'Cargando equipo',
                      child: const CircularProgressIndicator(),
                    ),
                  ),
                  TeamDetailFailure(:final failure) => ErrorView(
                    failure: failure,
                    onRetry: refresh,
                  ),
                  TeamDetailLoaded(:final detail) => RefreshIndicator(
                    onRefresh: _refresh,
                    child: _DetailBody(detail: detail, onRetry: refresh),
                  ),
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail, required this.onRetry});

  final TeamDetail detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final now = context.read<Clock>().now();
    final labels = {
      for (final m in [
        ...detail.upcoming,
        ...detail.played,
        ...detail.otherCompetitions,
      ])
        m.match.id: [
          m.competitionName,
          ?m.phaseLabel,
          m.stageLabel,
        ].join(' · '),
    };
    void open(Match m) => context.push(AppRoutes.matchDetail(m.id));
    final progress = detail.progress;
    final empty = detail.upcoming.isEmpty && detail.played.isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        _Header(detail: detail),
        _SyncStatus(progress: progress, onRetry: onRetry),
        if (empty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            child: Text(
              progress.isRunning
                  ? 'Buscando partidos…'
                  : 'No hay partidos de este equipo en las competiciones de '
                        'la app.',
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          const SectionHeader(title: 'Próximos'),
          if (detail.upcoming.isEmpty)
            const _EmptySection('No hay partidos por jugarse guardados.')
          else
            ...matchDayItems(
              matches: [for (final m in detail.upcoming) m.match],
              now: now,
              subtitle: (m) => labels[m.id],
              onTap: open,
            ),
          const SectionHeader(title: 'Disputados'),
          if (detail.played.isEmpty)
            const _EmptySection('Todavía no hay partidos disputados.')
          else
            ...matchDayItems(
              matches: [for (final m in detail.played) m.match],
              now: now,
              subtitle: (m) => labels[m.id],
              onTap: open,
              newestFirst: true,
            ),
        ],
        if (detail.otherCompetitions.isNotEmpty) ...[
          const SectionHeader(
            title: 'Otras competiciones (información parcial)',
            subtitle:
                'TheSportsDB informa solo el próximo y el último partido del '
                'equipo. La app no sigue estas competiciones: no tienen '
                'fixture ni detalle.',
          ),
          // Sin `onTap`: el partido no está entre los guardados, no tiene
          // detalle.
          ...matchDayItems(
            matches: [for (final m in detail.otherCompetitions) m.match],
            now: now,
            subtitle: (m) => labels[m.id],
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: Text(
            'Partidos guardados en este dispositivo · Horarios de Argentina',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

/// Cabecera de la ficha (Hito E, §11.1), sin tarjeta: escudo de 72, el
/// nombre con el favorito al lado (E-D14), estadio · ciudad y, debajo, a
/// todo el ancho, las competiciones de la app como chips discretos.
///
/// Si la palabra más ancha del nombre no entra al lado del escudo (texto
/// grande en un teléfono), el escudo va arriba y el nombre usa todo el
/// ancho; nunca se parte una palabra. Un chip que no entra en un renglón
/// usa dos (la letra no se achica).
class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final TeamDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final team = detail.team!;
    final info = detail.info;
    final place = [?info?.stadium, ?info?.location].join(' · ');
    final nameStyle = theme.textTheme.teamHeaderName.copyWith(
      color: colors.onSurface,
    );
    final badge = TeamBadge(
      name: team.name,
      url: team.badgeUrl,
      size: AppSizes.badgeHero,
    );
    final favorite = FavoriteButton(team: team);
    final name = Semantics(
      header: true,
      child: Text(team.name, style: nameStyle),
    );
    final competitions = [
      for (final id in detail.competitionIds) ?CompetitionCatalog.byId(id),
    ];
    final placeText = place.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              place,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          );
    final chips = competitions.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final c in competitions)
                  Chip(
                    label: Text(
                      c.name,
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                    ),
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onSurface,
                    ),
                    backgroundColor: colors.surfaceContainerHigh,
                    side: BorderSide.none,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.controlAll,
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final word = TextMeasure.of(
            context,
          ).widestWord([team.name], nameStyle);
          final besideBadge =
              constraints.maxWidth -
              AppSizes.badgeHero -
              AppSpacing.lg -
              AppSizes.tapTarget;
          // La estrella sigue al nombre (no al borde de la pantalla).
          final nameRow = Row(
            children: [
              Flexible(child: name),
              favorite,
            ],
          );
          if (word <= besideBadge) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    badge,
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [nameRow, ?placeText],
                      ),
                    ),
                  ],
                ),
                ?chips,
              ],
            );
          }
          // Si tampoco entra al lado de la estrella, ella sube junto al
          // escudo.
          final fitsBesideFavorite =
              word <= constraints.maxWidth - AppSizes.tapTarget;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  badge,
                  const Spacer(),
                  if (!fitsBesideFavorite) favorite,
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (fitsBesideFavorite) nameRow else name,
              ?placeText,
              ?chips,
            ],
          );
        },
      ),
    );
  }
}

/// Avance no bloqueante de la descarga de partidos, o por qué se detuvo.
class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.progress, required this.onRetry});

  final SyncProgress progress;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failure = progress.failure;
    if (progress.isRunning) {
      final total = progress.total;
      final text = total == 0
          ? 'Buscando partidos…'
          : 'Completando partidos… ${progress.done}/$total';
      return Semantics(
        liveRegion: true,
        label: text,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: total == 0 ? null : progress.done / total,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(text, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      );
    }
    if (failure == null) return const SizedBox.shrink();

    final (:title, message: _) = failureMessage(failure);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: InfoBanner(
        tone: InfoTone.offline,
        text:
            'No se pudieron completar los partidos '
            '(${progress.done}/${progress.total}). $title. '
            'Se muestran los guardados.',
        action: TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
