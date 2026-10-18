import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/calendar/calendar_event.dart';
import '../../../../core/platform/external_actions.dart';
import '../../../../core/time/argentina_time.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/presentation/formatters/match_labels.dart';
import '../../../../shared/presentation/layout/text_measure.dart';
import '../../../../shared/presentation/theme/app_palette.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/live_auto_refresh.dart';
import '../../../../shared/presentation/widgets/refresh_feedback.dart';
import '../../../../shared/presentation/widgets/status_views.dart';
import '../../../matches/domain/entities/kickoff.dart';
import '../../../matches/domain/entities/knockout_tie.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/entities/match_status.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../../../matches/domain/services/match_grouping.dart';
import '../../domain/entities/match_detail.dart';
import '../../domain/usecases/get_match_detail.dart';
import '../bloc/match_detail_bloc.dart';
import '../formatters/match_detail_texts.dart';
import '../widgets/match_hero.dart';

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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.xs,
              ),
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

  /// Con el partido en vivo se actualiza solo (D11).
  static bool _isLive(BuildContext context) {
    final state = context.read<MatchDetailBloc>().state;
    return state is MatchDetailLoaded &&
        !state.isRefreshing &&
        MatchGrouping.isLive(
          state.result.data.match,
          context.read<Clock>().now(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return LiveAutoRefresh(
      hasLiveMatches: () => _isLive(context),
      onTick: () =>
          context.read<MatchDetailBloc>().add(const MatchDetailLiveTick()),
      child: _content(context),
    );
  }

  Widget _content(BuildContext context) {
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
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (state.isRefreshing) const LinearProgressIndicator(),
            if (refreshError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: StaleDataBanner(
                  fetchedAt: state.result.fetchedAt,
                  failure: refreshError,
                  onRetry: () => context.read<MatchDetailBloc>().add(
                    const MatchDetailRefreshRequested(),
                  ),
                ),
              ),
            MatchHero(detail: detail, now: now),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: _ShareActions(
                detail: detail,
                now: now,
                fetchedAt: state.result.fetchedAt,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: _InfoGrid(
                items: [
                  _InfoItem(
                    label: 'Fecha',
                    value: MatchLabels.day(m.kickoff.argentinaDay),
                  ),
                  _InfoItem(
                    label: 'Hora (Argentina)',
                    value: MatchLabels.kickoffTime(m.kickoff),
                    note: m.kickoff.certainty == KickoffCertainty.tentative
                        ? 'La API informa 00:00 UTC (21:00 en Argentina), '
                              'sin confirmar.'
                        : null,
                  ),
                  if (m.previousKickoffUtc case final previous?)
                    _InfoItem(
                      label: 'Reprogramado',
                      value:
                          'Antes: ${MatchLabels.day(ArgentinaTime.dayOf(previous))}'
                          ' ${ArgentinaTime.formatTime(previous)}',
                    ),
                  if (MatchLabels.status(m.status, overdue: overdue)
                      case final status?)
                    _InfoItem(
                      label: 'Estado',
                      value: status,
                      note:
                          m.status.decidedBy == MatchDecision.penalties &&
                              m.penalties == null
                          ? 'TheSportsDB no informa el resultado de los '
                                'penales.'
                          : null,
                    ),
                  if (m.venue case final venue?)
                    _InfoItem(label: 'Estadio', value: venue),
                  // El global y quién avanza van en el héroe.
                  if (detail.tie case final tie? when tie.isSeries)
                    _InfoItem(
                      label: 'Serie de ida y vuelta',
                      value: _seriesText(tie),
                      wide: true,
                    ),
                  if (m.membership == MatchMembership.unconfirmed)
                    const _InfoItem(
                      label: 'Aviso',
                      value: 'La API ya no lo lista en esta fecha.',
                      wide: true,
                    ),
                ],
              ),
            ),
            if (m.videoUrl case final video?)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
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
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: ClipRRect(
                  borderRadius: AppRadius.groupAll,
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
              padding: const EdgeInsets.only(top: AppSpacing.lg),
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
}

/// Las piernas de la serie («Ida: Fortaleza 0-0 Vélez Sarsfield»), un
/// renglón cada una. El global va en el héroe.
String _seriesText(KnockoutTie tie) {
  String legText(Match leg) {
    final score = leg.score;
    if (score == null || !(leg.status.isFinished || leg.status.isInPlay)) {
      return '${leg.home.name} - ${leg.away.name}, '
          '${MatchLabels.day(leg.kickoff.argentinaDay)} · '
          '${MatchLabels.kickoffTime(leg.kickoff)}';
    }
    final shootout = leg.status.isFinished ? MatchLabels.penalties(leg) : null;
    return [
      '${leg.home.name} ${score.home}-${score.away} ${leg.away.name}',
      if (shootout != null) '($shootout en penales)',
      if (leg.status.isInPlay) '(en juego)',
    ].join(' ');
  }

  return [
    for (final (i, leg) in tie.legs.indexed)
      '${MatchLabels.leg(i)}: ${legText(leg)}',
    if (tie.legs.length < tie.expectedLegs)
      '${MatchLabels.leg(tie.legs.length)}: sin datos en TheSportsDB',
  ].join('\n');
}

/// Un dato del partido: etiqueta, valor y una nota opcional.
final class _InfoItem {
  const _InfoItem({
    required this.label,
    required this.value,
    this.note,
    this.wide = false,
  });

  final String label;
  final String value;
  final String? note;

  /// Ocupa todo el ancho aunque haya dos columnas (la serie, un aviso).
  final bool wide;
}

/// Datos del partido en filas compactas etiqueta | valor, sobre la
/// superficie de grupo con divisores. Con el ancho disponible de dos
/// columnas (600 px) van de a dos por renglón; en el panel de 440 px y en
/// los teléfonos, de a uno.
///
/// La columna de etiquetas se mide con la escala de texto: si alguna
/// palabra no entra, cada etiqueta va arriba de su valor.
class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});

  final List<_InfoItem> items;

  /// Ancho disponible desde el que van dos columnas.
  static const twoColumnsFrom = 600.0;

  /// Parte de la celda que puede ocupar la etiqueta.
  static const _labelShare = 0.4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labelStyle = theme.textTheme.bodyMedium!.copyWith(
      color: colors.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.bodyMedium!.copyWith(
      color: colors.onSurface,
    );

    return Material(
      color: AppPalette.of(context).group,
      borderRadius: AppRadius.groupAll,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= twoColumnsFrom ? 2 : 1;
          final cellInner = constraints.maxWidth / columns - 2 * AppSpacing.md;
          final measure = TextMeasure.of(context);
          final labels = [for (final i in items) i.label];
          final widestLabel = labels
              .map((l) => measure.width(l, labelStyle))
              .fold(0.0, math.max);
          final labelWidth = math.min(widestLabel, cellInner * _labelShare);
          final stacked = measure.widestWord(labels, labelStyle) > labelWidth;

          Widget cell(_InfoItem item) {
            final value = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.value, style: valueStyle),
                if (item.note case final note?) Text(note, style: labelStyle),
              ],
            );
            final label = Text(item.label, style: labelStyle);
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [label, value],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: labelWidth, child: label),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: value),
                      ],
                    ),
            );
          }

          // Renglones: los datos anchos van solos; los demás, de a dos.
          final lines = <List<_InfoItem>>[];
          for (final item in items) {
            final last = lines.lastOrNull;
            if (columns == 2 &&
                !item.wide &&
                last != null &&
                last.length == 1 &&
                !last.single.wide) {
              last.add(item);
            } else {
              lines.add([item]);
            }
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, line) in lines.indexed) ...[
                if (i > 0) const Divider(),
                if (columns == 1 || line.length == 1 && line.single.wide)
                  cell(line.first)
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cell(line.first)),
                      Expanded(
                        child: line.length > 1
                            ? cell(line[1])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// «Compartir» y, si el partido todavía no empezó, «Agregar al calendario».
class _ShareActions extends StatelessWidget {
  const _ShareActions({
    required this.detail,
    required this.now,
    required this.fetchedAt,
  });

  final MatchDetail detail;
  final DateTime now;
  final DateTime fetchedAt;

  static void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _share(BuildContext context) async {
    final outcome = await context.read<ExternalActions>().share(
      MatchDetailTexts.share(detail, now: now, fetchedAt: fetchedAt),
      subject: MatchDetailTexts.title(detail),
    );
    if (!context.mounted) return;
    switch (outcome) {
      case ShareOutcome.copied:
        _notify(context, 'Copiado al portapapeles.');
      case ShareOutcome.failed:
        _notify(context, 'No se pudo compartir.');
      case ShareOutcome.shared || ShareOutcome.dismissed:
    }
  }

  Future<void> _addToCalendar(BuildContext context, CalendarEvent event) async {
    final fileName = MatchDetailTexts.calendarFileName(detail);
    final outcome = await context.read<ExternalActions>().addToCalendar(
      event,
      fileName: fileName,
    );
    if (!context.mounted) return;
    switch (outcome) {
      case CalendarOutcome.downloaded:
        _notify(
          context,
          'Se descargó $fileName: abrilo para agregarlo a tu calendario.',
        );
      case CalendarOutcome.failed:
        _notify(context, 'No se pudo abrir el calendario.');
      case CalendarOutcome.opened:
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = MatchDetailTexts.calendarEvent(detail, now);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => _share(context),
          icon: const Icon(Icons.share_outlined),
          label: const Text('Compartir'),
        ),
        if (event != null)
          FilledButton.tonalIcon(
            onPressed: () => _addToCalendar(context, event),
            icon: const Icon(Icons.event_outlined),
            label: Text(
              event.time is AllDayEvent
                  ? 'Agregar al calendario (todo el día)'
                  : 'Agregar al calendario',
            ),
          ),
      ],
    );
  }
}
