import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/presentation/formatters/match_labels.dart';
import '../../../../shared/presentation/widgets/match_status_chip.dart';
import '../../../../shared/presentation/widgets/refresh_feedback.dart';
import '../../../../shared/presentation/widgets/status_views.dart';
import '../../../../shared/presentation/widgets/team_badge.dart';
import '../../../competitions/domain/entities/phase.dart';
import '../../../competitions/domain/entities/phase_assignment.dart';
import '../../../matches/domain/entities/kickoff.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/entities/match_status.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../../domain/entities/match_detail.dart';
import '../../domain/usecases/get_match_detail.dart';
import '../bloc/match_detail_bloc.dart';

/// Detalle de un partido a pantalla completa (`/partidos/:id`).
class MatchDetailPage extends StatelessWidget {
  const MatchDetailPage({super.key, required this.matchId});

  final int matchId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _createBloc(context, matchId),
      child: const _MatchDetailView(),
    );
  }
}

/// Detalle de un partido dentro de otra pantalla (panel del fixture en
/// escritorio).
class MatchDetailPanel extends StatelessWidget {
  const MatchDetailPanel({
    super.key,
    required this.matchId,
    required this.onClose,
  });

  final int matchId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _createBloc(context, matchId),
      child: _MatchDetailPanelView(matchId: matchId, onClose: onClose),
    );
  }
}

MatchDetailBloc _createBloc(BuildContext context, int matchId) =>
    MatchDetailBloc(GetMatchDetail(context.read<MatchRepository>()))
      ..add(MatchDetailStarted(matchId));

bool _isRefreshing(MatchDetailState state) =>
    state is MatchDetailLoading ||
    state is MatchDetailLoaded && state.isRefreshing;

/// Actualiza y, si no hizo falta consultar la red (se actualizó hace menos
/// de 30 s), lo avisa.
Future<void> _refresh(BuildContext context) async {
  final bloc = context.read<MatchDetailBloc>();
  final before = switch (bloc.state) {
    MatchDetailLoaded(:final result) => result.fetchedAt,
    _ => null,
  };
  bloc.add(const MatchDetailRefreshRequested());
  final after = await bloc.stream.firstWhere((s) => !_isRefreshing(s));
  if (after case MatchDetailLoaded(:final result)
      when context.mounted &&
          result.refreshError == null &&
          result.fetchedAt == before) {
    showAlreadyUpToDate(context, result.fetchedAt);
  }
}

class _MatchDetailView extends StatelessWidget {
  const _MatchDetailView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MatchDetailBloc, MatchDetailState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            // Por enlace directo no hay a dónde volver: se ofrece el inicio.
            leading: Navigator.canPop(context)
                ? null
                : IconButton(
                    tooltip: 'Ir al inicio',
                    onPressed: () => context.go(AppRoutes.home),
                    icon: const Icon(Icons.home_outlined),
                  ),
            title: const Text('Partido'),
            actions: [
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _isRefreshing(state)
                    ? null
                    : () => _refresh(context),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _MatchDetailContent(state: state),
        );
      },
    );
  }
}

class _MatchDetailPanelView extends StatelessWidget {
  const _MatchDetailPanelView({required this.matchId, required this.onClose});

  final int matchId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MatchDetailBloc, MatchDetailState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Partido',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Actualizar',
                    onPressed: _isRefreshing(state)
                        ? null
                        : () => _refresh(context),
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: 'Abrir en pantalla completa',
                    onPressed: () =>
                        context.push(AppRoutes.matchDetail(matchId)),
                    icon: const Icon(Icons.open_in_full),
                  ),
                  IconButton(
                    tooltip: 'Cerrar detalle',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _MatchDetailContent(state: state)),
          ],
        );
      },
    );
  }
}

class _MatchDetailContent extends StatelessWidget {
  const _MatchDetailContent({required this.state});

  final MatchDetailState state;

  @override
  Widget build(BuildContext context) {
    final state = this.state;
    return switch (state) {
      MatchDetailInitial() || MatchDetailLoading() => Center(
        child: Semantics(
          label: 'Cargando partido',
          child: const CircularProgressIndicator(),
        ),
      ),
      MatchDetailFailure(:final failure) => ErrorView(
        failure: failure,
        onRetry: () => context.read<MatchDetailBloc>().add(
          const MatchDetailRefreshRequested(),
        ),
      ),
      MatchDetailLoaded() => RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: _DetailBody(state: state),
      ),
    };
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.state});

  final MatchDetailLoaded state;

  @override
  Widget build(BuildContext context) {
    final detail = state.result.data;
    final m = detail.match;
    final now = context.read<Clock>().now();
    final overdue = m.isResultOverdue(now);
    final refreshError = state.result.refreshError;
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (state.isRefreshing) const LinearProgressIndicator(),
            if (refreshError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StaleDataBanner(
                  fetchedAt: state.result.fetchedAt,
                  failure: refreshError,
                  onRetry: () => context.read<MatchDetailBloc>().add(
                    const MatchDetailRefreshRequested(),
                  ),
                ),
              ),
            Text(
              detail.competitionName,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (_phaseAndStage(detail) case final stage?)
              Text(
                stage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            const SizedBox(height: 16),
            _Scoreboard(match: m, overdue: overdue),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  _InfoTile(
                    icon: Icons.calendar_today,
                    label: 'Fecha',
                    value: MatchLabels.day(m.kickoff.argentinaDay),
                  ),
                  _InfoTile(
                    icon: Icons.schedule,
                    label: 'Hora (Argentina)',
                    value: MatchLabels.kickoffTime(m.kickoff),
                    note: m.kickoff.certainty == KickoffCertainty.tentative
                        ? 'La API informa 00:00 UTC (21:00 en Argentina), '
                              'sin confirmar.'
                        : null,
                  ),
                  if (m.previousKickoffUtc case final previous?)
                    _InfoTile(
                      icon: Icons.update,
                      label: 'Reprogramado',
                      value:
                          'Antes: ${MatchLabels.day(ArgentinaTime.dayOf(previous))}'
                          ' ${ArgentinaTime.formatTime(previous)}',
                    ),
                  if (MatchLabels.status(m.status, overdue: overdue)
                      case final status?)
                    _InfoTile(
                      icon: Icons.flag_outlined,
                      label: 'Estado',
                      value: status,
                      note: m.status.decidedBy == MatchDecision.penalties
                          ? 'TheSportsDB no informa el resultado de los '
                                'penales.'
                          : null,
                    ),
                  if (m.venue case final venue?)
                    _InfoTile(
                      icon: Icons.stadium_outlined,
                      label: 'Estadio',
                      value: venue,
                    ),
                  if (m.membership == MatchMembership.unconfirmed)
                    const _InfoTile(
                      icon: Icons.help_outline,
                      label: 'Aviso',
                      value: 'La API ya no lo lista en esta fecha.',
                    ),
                ],
              ),
            ),
            if (m.videoUrl case final video?)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton.tonalIcon(
                  onPressed: () => launchUrl(
                    Uri.parse(video),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Ver video'),
                ),
              ),
            if (m.thumbUrl case final thumb?)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    thumb,
                    fit: BoxFit.cover,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    semanticLabel: 'Imagen del partido',
                    // Si no carga (sin red), no se muestra nada.
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Actualizado el '
                '${ArgentinaTime.formatDay(ArgentinaTime.dayOf(state.result.fetchedAt))}'
                ' a las ${ArgentinaTime.formatTime(state.result.fetchedAt)}'
                ' · Horarios de Argentina',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// «Clausura · Fecha 12», «Cuartos de final», «Ronda 16 · sin fase».
  static String? _phaseAndStage(MatchDetail detail) {
    final PhaseAssignment? phase = detail.phase;
    final stage = detail.stageLabel;
    if (phase == null || stage == null) return stage;
    if (!phase.isDetermined) return '$stage · ${PhaseKey.undetermined.label}';
    return phase.phase == PhaseKey.unica || phase.phase == PhaseKey.regular
        ? stage
        : '${phase.phase.label} · $stage';
  }
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.match, required this.overdue});

  final Match match;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = match.score;
    final showScore =
        score != null && (match.status.isFinished || match.status.isInPlay);

    Widget team(String name, String? badge) => Expanded(
      child: Column(
        children: [
          TeamBadge(name: name, url: badge, size: 64),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
        ],
      ),
    );

    return Semantics(
      label: MatchLabels.semantics(match, overdue: overdue),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          team(match.home.name, match.home.badgeUrl),
          SizedBox(
            width: 120,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  showScore
                      ? '${score.home} – ${score.away}'
                      : match.kickoff.isConfirmed
                      ? MatchLabels.kickoffTime(match.kickoff)
                      : 'vs',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: match.status.isInPlay
                        ? theme.colorScheme.error
                        : null,
                  ),
                ),
                const SizedBox(height: 6),
                MatchStatusChip(status: match.status, overdue: overdue),
              ],
            ),
          ),
          team(match.away.name, match.away.badgeUrl),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.note,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(value),
      subtitle: Text(note == null ? label : '$label · $note'),
    );
  }
}
