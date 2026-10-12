import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/presentation/formatters/failure_messages.dart';
import '../../../../shared/presentation/widgets/match_day_list.dart';
import '../../../../shared/presentation/widgets/section_header.dart';
import '../../../../shared/presentation/widgets/status_views.dart';
import '../../../../shared/presentation/widgets/team_badge.dart';
import '../../../competitions/domain/catalog/competition_catalog.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/repositories/match_repository.dart';
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

class _TeamDetailView extends StatelessWidget {
  const _TeamDetailView();

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
            actions: [
              IconButton(
                tooltip: 'Actualizar',
                onPressed: state.isBusy ? null : refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: Align(
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
                  onRefresh: () async {
                    refresh();
                    await bloc.stream.firstWhere((s) => !s.isBusy);
                  },
                  child: _DetailBody(detail: detail, onRetry: refresh),
                ),
              },
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
      for (final m in [...detail.upcoming, ...detail.played])
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
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        _SyncStatus(progress: progress, onRetry: onRetry),
        _Header(detail: detail),
        if (empty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
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
        Padding(
          padding: const EdgeInsets.only(top: 16),
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

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final TeamDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final team = detail.team!;
    final info = detail.info;
    final place = [?info?.stadium, ?info?.location].join(' · ');
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            TeamBadge(name: team.name, url: team.badgeUrl, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(team.name, style: theme.textTheme.titleLarge),
                  if (place.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(place, style: theme.textTheme.bodyMedium),
                    ),
                  if (detail.competitionIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final id in detail.competitionIds)
                            if (CompetitionCatalog.byId(id) case final c?)
                              Chip(
                                avatar: const Icon(
                                  Icons.emoji_events_outlined,
                                  size: 18,
                                ),
                                label: Text(c.name),
                                visualDensity: VisualDensity.compact,
                              ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avance no bloqueante de la descarga de partidos, o por qué se detuvo.
class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.progress, required this.onRetry});

  final TeamSyncProgress progress;
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
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: total == 0 ? null : progress.done / total,
              ),
              const SizedBox(height: 4),
              Text(text, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      );
    }
    if (failure == null) return const SizedBox.shrink();

    final colors = theme.colorScheme;
    final (:title, message: _) = failureMessage(failure);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: colors.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Icon(Icons.cloud_off, color: colors.onTertiaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No se pudieron completar los partidos '
                    '(${progress.done}/${progress.total}). $title. '
                    'Se muestran los guardados.',
                    style: TextStyle(color: colors.onTertiaryContainer),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('Reintentar')),
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
