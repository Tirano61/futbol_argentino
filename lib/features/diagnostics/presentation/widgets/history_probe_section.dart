import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/time/argentina_time.dart';
import '../../../../core/time/clock.dart';
import '../../../competitions/domain/catalog/competition_catalog.dart';
import '../../../competitions/domain/entities/season.dart';
import '../../../competitions/domain/entities/season_completion.dart';
import '../bloc/history_probe_bloc.dart';

/// Historial a pedido (Fase 12): completa una temporada con prioridad P2 y
/// muestra qué se pidió y qué no. Las peticiones reales aparecen como
/// `GET …` en el log.
class HistoryProbeSection extends StatefulWidget {
  const HistoryProbeSection({super.key});

  @override
  State<HistoryProbeSection> createState() => _HistoryProbeSectionState();
}

class _HistoryProbeSectionState extends State<HistoryProbeSection> {
  var _competition = CompetitionCatalog.all.first;
  late final List<Season> _seasons = CompetitionCatalog.supportedSeasons(
    Season(ArgentinaTime.dayOf(context.read<Clock>().now()).year),
  );
  late var _season = _seasons.first;

  @override
  void initState() {
    super.initState();
    context.read<HistoryProbeBloc>().add(const HistoryProbeSummaryRequested());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocBuilder<HistoryProbeBloc, HistoryProbeState>(
          builder: (context, state) {
            final bloc = context.read<HistoryProbeBloc>();
            void start({bool force = false}) => bloc.add(
              HistoryProbeStarted(
                competitionId: _competition.id,
                season: _season,
                forceRefresh: force,
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Historial', style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Completa una temporada a pedido (P2: 10 rondas por minuto, '
                  'de a una). No vuelve a pedir lo vigente, ni las rondas '
                  'cerradas o históricas salvo «Forzar vencidas».',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in CompetitionCatalog.all)
                      ChoiceChip(
                        label: Text(d.shortName),
                        selected: d == _competition,
                        onSelected: (_) => setState(() => _competition = d),
                      ),
                    for (final s in _seasons)
                      ChoiceChip(
                        label: Text(s.apiValue),
                        selected: s == _season,
                        onSelected: (_) => setState(() => _season = s),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: state.running ? null : start,
                      icon: const Icon(Icons.history),
                      label: const Text('Completar temporada'),
                    ),
                    OutlinedButton.icon(
                      onPressed: state.running
                          ? null
                          : () => start(force: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Forzar vencidas'),
                    ),
                    OutlinedButton.icon(
                      onPressed: state.running
                          ? () => bloc.add(const HistoryProbeCancelled())
                          : null,
                      icon: const Icon(Icons.stop),
                      label: const Text('Cancelar'),
                    ),
                  ],
                ),
                if (state.completion case final completion?) ...[
                  const SizedBox(height: 12),
                  _CompletionView(state: state, completion: completion),
                ],
                const SizedBox(height: 12),
                Text('Temporadas guardadas', style: textTheme.titleSmall),
                const SizedBox(height: 4),
                if (state.summaries.isEmpty)
                  const Text('Sin partidos guardados.')
                else
                  for (final s in state.summaries)
                    Text(
                      '${s.competitionName} ${s.season}: ${s.matchCount} '
                      'partidos · ${s.orphanedCount} sin confirmar · '
                      '${s.removedCount} dados de baja',
                    ),
                const SizedBox(height: 8),
                Text(
                  'Limpieza automática: desactivada. Solo borraría partidos '
                  'dados de baja y verificados con lookupevent hace más de 30 '
                  'días, y esa verificación todavía no existe.',
                  style: textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CompletionView extends StatelessWidget {
  const _CompletionView({required this.state, required this.completion});

  final HistoryProbeState state;
  final SeasonCompletion completion;

  static String _label(RoundCompletionStatus status) => switch (status) {
    RoundCompletionStatus.missing => 'falta',
    RoundCompletionStatus.stale => 'vencida',
    RoundCompletionStatus.fresh => 'vigente',
    RoundCompletionStatus.settled => 'cerrada',
    RoundCompletionStatus.historic => 'histórica',
    RoundCompletionStatus.fetched => 'descargada',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = completion.progress;
    final name =
        CompetitionCatalog.byId(completion.competitionId)?.shortName ??
        '${completion.competitionId}';
    final status = state.cancelled
        ? 'cancelado'
        : progress.isRunning
        ? 'completando…'
        : progress.failure != null
        ? 'detenido por un error'
        : 'terminado';
    final failure = progress.failure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$name ${completion.season}${state.forced ? ' (forzada)' : ''}: '
          '$status · rondas al día ${progress.done}/${progress.total} · '
          'consultas ${progress.fetched} · '
          '${completion.matches.length} partidos guardados',
        ),
        if (state.running) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.total == 0 ? null : progress.done / progress.total,
          ),
        ],
        if (failure != null)
          SelectableText(
            '${failure.runtimeType}: ${failure.detail}',
            style: TextStyle(color: colors.error, fontSize: 12),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final r in completion.rounds)
              Text('r${r.apiRound} ${_label(r.status)}'),
          ],
        ),
      ],
    );
  }
}
