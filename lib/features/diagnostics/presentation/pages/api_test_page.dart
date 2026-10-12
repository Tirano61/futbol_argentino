import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/api_query_result.dart';
import '../../domain/entities/football_match.dart';
import '../../../../core/error/failure.dart';
import '../bloc/api_test_bloc.dart';
import '../../../../core/time/argentina_time.dart';
import '../widgets/badge_probe_section.dart';
import '../widgets/cache_probe_section.dart';
import '../widgets/history_probe_section.dart';
import '../widgets/package_probe_section.dart';

class ApiTestPage extends StatelessWidget {
  const ApiTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prueba TheSportsDB')),
      body: BlocBuilder<ApiTestBloc, ApiTestState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Primera Nacional · id ${ApiTestBloc.leagueId} · '
                'fecha ${ApiTestBloc.round} · temporada ${ApiTestBloc.season}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: state is ApiTestLoading
                    ? null
                    : () => context.read<ApiTestBloc>().add(
                        const ApiQueryRequested(),
                      ),
                icon: const Icon(Icons.cloud_download),
                label: const Text('Consultar API'),
              ),
              const SizedBox(height: 16),
              const CacheProbeSection(),
              const SizedBox(height: 16),
              const HistoryProbeSection(),
              const SizedBox(height: 16),
              const BadgeProbeSection(),
              const SizedBox(height: 16),
              const PackageProbeSection(),
              const SizedBox(height: 16),
              ...switch (state) {
                ApiTestInitial() => [
                  const Text('Presioná "Consultar API" para hacer la prueba.'),
                ],
                ApiTestLoading() => [
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  const Center(child: Text('Consultando TheSportsDB…')),
                ],
                ApiTestSuccess(:final result) => _successContent(result),
                ApiTestFailure(:final failure) => _failureContent(failure),
              },
            ],
          );
        },
      ),
    );
  }

  List<Widget> _successContent(ApiQueryResult result) => [
    _InfoCard(
      rows: [
        ('Estado HTTP', '${result.statusCode}'),
        ('Tiempo', '${result.elapsedMs} ms'),
        ('Partidos recibidos', '${result.matches.length}'),
      ],
    ),
    if (result.matches.isEmpty)
      const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Respuesta válida sin partidos: el campo "events" vino vacío o '
            'null.',
          ),
        ),
      ),
    for (final match in result.matches) _MatchCard(match: match),
    const SizedBox(height: 8),
    _RawContentPanel(title: 'Ver JSON completo', content: result.prettyJson),
  ];

  List<Widget> _failureContent(Failure failure) => [
    _ErrorCard(failure: failure),
    if (failure.responseBody != null) ...[
      const SizedBox(height: 8),
      _RawContentPanel(
        title: 'Ver respuesta completa del servidor',
        content: failure.responseBody!.isEmpty
            ? '(cuerpo vacío)'
            : failure.responseBody!,
      ),
    ],
  ];
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(label)),
                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.bold),
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

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final FootballMatch match;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final argentina = formatArgentinaDateTime(match.kickoffUtc);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${match.homeTeam} vs ${match.awayTeam}',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            if (argentina == null)
              const Text('Horario no disponible')
            else ...[
              Text('Fecha: ${argentina.date}'),
              Text('Hora Argentina: ${argentina.time}'),
            ],
            Text(
              match.hasResult
                  ? 'Resultado: ${match.homeScore} - ${match.awayScore}'
                  : 'Sin resultado',
            ),
          ],
        ),
      ),
    );
  }
}

String _label(Failure failure) => switch (failure) {
  NetworkFailure(issue: NetworkIssue.timeout) => 'Timeout',
  NetworkFailure(issue: NetworkIssue.connection) => 'Error de conexión',
  NetworkFailure(issue: NetworkIssue.possibleCors) =>
    'Error de conexión / posible bloqueo CORS (Flutter Web)',
  RateLimitFailure() => 'Límite de peticiones (HTTP 429)',
  ServerFailure() => 'Error HTTP',
  NotFoundFailure() => 'No encontrado',
  FormatFailure() => 'Error de formato JSON',
};

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: colors.onErrorContainer),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _label(failure),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (failure.statusCode != null)
                Text('Estado HTTP: ${failure.statusCode}'),
              if (failure.elapsed != null)
                Text('Tiempo: ${failure.elapsed!.inMilliseconds} ms'),
              const SizedBox(height: 8),
              SelectableText(
                failure.detail,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RawContentPanel extends StatefulWidget {
  const _RawContentPanel({required this.title, required this.content});

  final String title;
  final String content;

  @override
  State<_RawContentPanel> createState() => _RawContentPanelState();
}

class _RawContentPanelState extends State<_RawContentPanel> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(widget.title),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 400,
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  widget.content,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
