import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/presentation/formatters/failure_messages.dart';
import '../../../../shared/presentation/widgets/status_views.dart';
import '../../../../shared/presentation/widgets/team_badge.dart';
import '../../../competitions/domain/catalog/competition_catalog.dart';
import '../../../favorites/presentation/widgets/favorite_button.dart';
import '../../../matches/domain/repositories/match_repository.dart';
import '../../domain/entities/team_summary.dart';
import '../../domain/repositories/team_repository.dart';
import '../../domain/usecases/ensure_team_index.dart';
import '../../domain/usecases/search_teams_online.dart';
import '../bloc/team_search_bloc.dart';

/// Buscador de equipos de todas las competiciones (`/equipos?q=`).
class TeamSearchPage extends StatelessWidget {
  const TeamSearchPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  Widget build(BuildContext context) {
    final teams = context.read<TeamRepository>();
    return BlocProvider(
      create: (context) => TeamSearchBloc(
        teams: teams,
        ensureIndex: EnsureTeamIndex(context.read<MatchRepository>()),
        searchOnline: SearchTeamsOnline(teams),
        clock: context.read<Clock>(),
      )..add(TeamSearchStarted(initialQuery: initialQuery)),
      child: _TeamSearchView(initialQuery: initialQuery),
    );
  }
}

class _TeamSearchView extends StatefulWidget {
  const _TeamSearchView({required this.initialQuery});

  final String initialQuery;

  @override
  State<_TeamSearchView> createState() => _TeamSearchViewState();
}

class _TeamSearchViewState extends State<_TeamSearchView> {
  late final _controller = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    context.read<TeamSearchBloc>().add(const TeamSearchCleared());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TeamSearchBloc, TeamSearchState>(
      listenWhen: (previous, current) => previous.query != current.query,
      listener: (context, state) {
        // En Web, la URL refleja la búsqueda para poder compartirla.
        if (kIsWeb) {
          final q = state.query.trim();
          SystemNavigator.routeInformationUpdated(
            uri: Uri(
              path: AppRoutes.teams,
              queryParameters: q.isEmpty ? null : {'q': q},
            ),
            replace: true,
          );
        }
      },
      builder: (context, state) {
        final indexFailure = state.indexFailure;
        return Scaffold(
          appBar: AppBar(title: const Text('Equipos')),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Buscar equipo',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: state.query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Borrar búsqueda',
                                onPressed: _clear,
                                icon: const Icon(Icons.clear),
                              ),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (text) => context.read<TeamSearchBloc>().add(
                        TeamSearchQueryChanged(text),
                      ),
                    ),
                  ),
                  if (state.isIndexing)
                    Semantics(
                      label: 'Cargando equipos',
                      child: const LinearProgressIndicator(),
                    ),
                  if (indexFailure != null && !state.isIndexing)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: _IndexNotice(
                        failure: indexFailure,
                        hasTeams: state.indexSize > 0,
                      ),
                    ),
                  Expanded(child: _Results(state: state)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.state});

  final TeamSearchState state;

  @override
  Widget build(BuildContext context) {
    return switch (state.results) {
      // Hay texto y todavía corre la espera (debounce): sin invitación.
      TeamSearchIdle() when state.query.trim().isNotEmpty =>
        const SizedBox.shrink(),
      TeamSearchIdle() => EmptyView(
        icon: Icons.shield_outlined,
        title: 'Buscá un equipo',
        message: state.indexSize > 0
            ? 'Hay ${state.indexSize} equipos de '
                  '${CompetitionCatalog.all.map((c) => c.name).join(', ')}. '
                  'Probá con «river» o «gimnasia».'
            : 'Escribí el nombre del equipo, por ejemplo «river».',
      ),
      TeamSearchSearching() => Center(
        child: Semantics(
          label: 'Buscando equipos',
          child: const CircularProgressIndicator(),
        ),
      ),
      TeamSearchNoResults(:final onlineFailure) => EmptyView(
        icon: Icons.search_off,
        title: 'No se encontraron equipos',
        message: onlineFailure == null
            ? 'Probá con otra parte del nombre.'
            : 'No hay coincidencias en los equipos guardados y la búsqueda '
                  'en línea falló: ${failureMessage(onlineFailure).title}.',
      ),
      TeamSearchFound(:final teams, :final isOnline) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        children: [
          if (isOnline)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Text(
                'Sin coincidencias en los equipos guardados. '
                'Resultados de TheSportsDB:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          for (final team in teams)
            _TeamTile(key: ValueKey(team.team.id), team: team),
        ],
      ),
    };
  }
}

class _TeamTile extends StatelessWidget {
  const _TeamTile({super.key, required this.team});

  final TeamSummary team;

  @override
  Widget build(BuildContext context) {
    // En el orden del catálogo: Primera, Nacional, Copa.
    final competitions = [
      for (final c in CompetitionCatalog.all)
        if (team.competitionIds.contains(c.id)) c.name,
    ];
    return Card(
      child: ListTile(
        leading: TeamBadge(name: team.team.name, url: team.team.badgeUrl),
        title: Text(team.team.name),
        subtitle: competitions.isEmpty ? null : Text(competitions.join(' · ')),
        trailing: FavoriteButton(team: team.team),
        onTap: () => context.push(AppRoutes.teamDetail(team.team.id)),
      ),
    );
  }
}

/// No se pudieron descargar los equipos de las competiciones.
class _IndexNotice extends StatelessWidget {
  const _IndexNotice({required this.failure, required this.hasTeams});

  final Failure failure;
  final bool hasTeams;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (:title, message: _) = failureMessage(failure);
    return Semantics(
      liveRegion: true,
      child: Material(
        color: hasTeams ? colors.tertiaryContainer : colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            hasTeams
                ? 'Se busca entre los equipos guardados. $title.'
                : 'No se pudo cargar la lista de equipos. $title.',
            style: TextStyle(
              color: hasTeams
                  ? colors.onTertiaryContainer
                  : colors.onErrorContainer,
            ),
          ),
        ),
      ),
    );
  }
}
