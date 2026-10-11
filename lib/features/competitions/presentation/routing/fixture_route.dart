import '../../domain/catalog/competition_catalog.dart';
import '../../domain/entities/phase.dart';
import '../../domain/entities/season.dart';
import '../../domain/entities/stage.dart';
import '../bloc/competition_fixture_bloc.dart';

/// URL del fixture: `/competiciones/4406?temporada=2026&fase=clausura&ronda=12`
/// (`&etapa=eliminatoria` en etapas de eliminación).
abstract final class FixtureRoute {
  static const basePath = '/competiciones';

  static const _phaseNames = {
    PhaseKey.apertura: 'apertura',
    PhaseKey.clausura: 'clausura',
    PhaseKey.regular: 'regular',
    PhaseKey.unica: 'copa',
    PhaseKey.undetermined: 'sin-fase',
  };

  /// Evento inicial a partir de la URL. Lo que no se entiende se ignora.
  static FixtureOpened parse({
    String? leagueId,
    Map<String, String> query = const {},
  }) {
    final id = int.tryParse(leagueId ?? '');
    final phaseName = query['fase'];
    return FixtureOpened(
      competitionId: id != null && CompetitionCatalog.byId(id) != null
          ? id
          : CompetitionCatalog.primeraDivision.id,
      season: Season.tryParse(query['temporada']),
      phase: _phaseNames.entries
          .where((e) => e.value == phaseName)
          .firstOrNull
          ?.key,
      apiRound: int.tryParse(query['ronda'] ?? ''),
      kind: query['etapa'] == 'eliminatoria'
          ? StageKind.knockout
          : StageKind.regular,
    );
  }

  /// URL de una etapa.
  static Uri uriFor(Stage stage) => Uri(
    path: '$basePath/${stage.competitionId}',
    queryParameters: {
      'temporada': stage.season.apiValue,
      'fase': _phaseNames[stage.phase]!,
      'ronda': '${stage.apiRound}',
      if (stage.kind == StageKind.knockout) 'etapa': 'eliminatoria',
    },
  );
}
