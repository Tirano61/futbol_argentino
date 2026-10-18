import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../shared/presentation/formatters/match_labels.dart';
import '../../../../shared/presentation/theme/app_spacing.dart';
import '../../../../shared/presentation/theme/app_text.dart';
import '../../../../shared/presentation/widgets/match_card.dart';
import '../../../../shared/presentation/widgets/match_group.dart';
import '../../../../shared/presentation/widgets/section_header.dart';
import '../../../../shared/presentation/widgets/team_badge.dart';
import '../../domain/entities/favorite_team_overview.dart';
import '../../domain/entities/home_feed.dart';
import '../bloc/home_favorites_bloc.dart';
import 'home_match_list.dart';

/// «Tus equipos»: un bloque por favorito con su próximo partido y el
/// último, con lo guardado (sin peticiones).
class FavoriteTeamsSection extends StatelessWidget {
  const FavoriteTeamsSection({super.key, required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return switch (context.watch<HomeFavoritesBloc>().state) {
      HomeFavoritesLoading() => const SizedBox.shrink(),
      HomeFavoritesUnavailable() => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: 'Tus equipos'),
          HomeEmptyMessage('No se pudieron leer tus equipos guardados.'),
        ],
      ),
      HomeFavoritesLoaded(:final teams) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Tus equipos'),
          if (teams.isEmpty)
            const HomeEmptyMessage(
              'Tocá la estrella de un equipo, en el buscador o en su ficha, '
              'para seguirlo desde acá.',
            )
          else
            for (final (i, t) in teams.indexed) ...[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              _FavoriteTeam(key: ValueKey(t.team.teamId), team: t, now: now),
            ],
        ],
      ),
    };
  }
}

/// El equipo como encabezado (lleva a su ficha) y debajo hasta dos filas:
/// el próximo partido (o el que se está jugando) y el último.
class _FavoriteTeam extends StatelessWidget {
  const _FavoriteTeam({super.key, required this.team, required this.now});

  final FavoriteTeamOverview team;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final favorite = team.team;
    final next = team.next;
    final last = team.last;

    // El contexto va una vez, en la fila: «Próximo · Domingo 18/10/2026 ·
    // Primera División · Clausura · Fecha 13». En juego no lleva el día ni
    // «En juego»: lo dicen el marcador y la etiqueta de la fila.
    Widget row(String? lead, HomeMatch m) => MatchCard(
      match: m.match,
      now: now,
      subtitleLead: lead,
      subtitle: [
        if (lead != null) MatchLabels.day(m.match.kickoff.argentinaDay),
        m.competitionName,
        ?m.phaseLabel,
        m.stageLabel,
      ].join(' · '),
      onTap: () => context.push(AppRoutes.matchDetail(m.match.id)),
    );

    return MatchGroup(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          visualDensity: VisualDensity.compact,
          leading: TeamBadge(name: favorite.name, url: favorite.badgeUrl),
          title: Text(
            favorite.name,
            style: theme.textTheme.groupTitle.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          // La ficha dentro de Favoritos: «atrás» vuelve a la lista.
          onTap: () => context.go(AppRoutes.favoriteTeam(favorite.teamId)),
        ),
        if (!team.hasMatches)
          const MatchGroupNote(
            'Sin partidos guardados. Abrí la ficha para buscarlos.',
          ),
        if (next != null)
          row(next.match.status.isInPlay ? null : 'Próximo', next),
        if (last != null) row('Último', last),
      ],
    );
  }
}
