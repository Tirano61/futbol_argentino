import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/catalog/competition_catalog.dart';
import '../../domain/entities/phase.dart';
import '../../domain/entities/season.dart';
import '../../domain/entities/stage.dart';
import '../bloc/competition_fixture_bloc.dart';

/// Selectores de competición, temporada y fase.
class FixtureSelectors extends StatelessWidget {
  const FixtureSelectors({super.key, required this.state});

  final CompetitionFixtureState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CompetitionFixtureBloc>();
    final definition = state.definition;
    final season = state.season;
    final phase = state.phase;
    final showPhases = state.phases.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<int>(
          segments: [
            for (final c in CompetitionCatalog.all)
              ButtonSegment(
                value: c.id,
                label: Text(c.shortName),
                tooltip: c.name,
              ),
          ],
          selected: {if (definition != null) definition.id},
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (ids) {
            if (ids.isNotEmpty) bloc.add(FixtureCompetitionChanged(ids.first));
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (season != null && state.seasons.isNotEmpty)
              // Su ancho natural, sin pasar el de la fila (texto grande).
              IntrinsicWidth(
                child: DropdownButton<Season>(
                  value: season,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final s in state.seasons)
                      DropdownMenuItem(
                        value: s,
                        child: Text(
                          'Temporada ${s.apiValue}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (s) {
                    if (s != null && s != season) {
                      bloc.add(FixtureSeasonChanged(s));
                    }
                  },
                ),
              ),
            if (showPhases)
              for (final p in state.phases)
                ChoiceChip(
                  label: Text(p.label),
                  selected: p == phase,
                  onSelected: (_) {
                    if (p != phase) bloc.add(FixturePhaseChanged(p));
                  },
                ),
          ],
        ),
        if (state.undeterminedInRound > 0 && phase != PhaseKey.undetermined)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  bloc.add(const FixturePhaseChanged(PhaseKey.undetermined)),
              icon: const Icon(Icons.help_outline, size: 18),
              label: Text(
                state.undeterminedInRound == 1
                    ? '1 partido de esta ronda sin fase determinada'
                    : '${state.undeterminedInRound} partidos de esta ronda '
                          'sin fase determinada',
              ),
            ),
          ),
      ],
    );
  }
}

/// Fecha o ronda actual, con anterior y siguiente.
class StageNavigator extends StatelessWidget {
  const StageNavigator({super.key, required this.state});

  final CompetitionFixtureState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CompetitionFixtureBloc>();
    final stage = state.stage;
    if (stage == null) return const SizedBox.shrink();

    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Anterior',
          onPressed: state.hasPrevious
              ? () => bloc.add(const FixturePreviousStageRequested())
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: DropdownButton<Stage>(
              value: stage,
              isExpanded: true,
              alignment: Alignment.center,
              underline: const SizedBox.shrink(),
              style: Theme.of(context).textTheme.titleMedium,
              items: [
                for (final s in state.stages)
                  DropdownMenuItem(
                    value: s,
                    alignment: Alignment.center,
                    child: Text(s.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (s) {
                if (s != null && s != stage) bloc.add(FixtureStageChanged(s));
              },
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Siguiente',
          onPressed: state.hasNext
              ? () => bloc.add(const FixtureNextStageRequested())
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
