import '../../domain/catalog/competition_catalog.dart';
import '../../domain/entities/phase.dart';
import '../../domain/entities/season.dart';
import '../../domain/entities/stage.dart';
import '../bloc/competition_fixture_bloc.dart';

/// Vista de la pantalla de competiciones.
enum CompetitionsView { fixture, table }

/// URL del fixture: `/competiciones/4406?temporada=2026&fase=clausura&ronda=12`
/// (`&etapa=eliminatoria` en etapas de eliminación). Tablas:
/// `/competiciones/4406?temporada=2026&vista=tabla&tabla=apertura-a`.
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

  static CompetitionsView parseView(Map<String, String> query) =>
      query['vista'] == 'tabla'
      ? CompetitionsView.table
      : CompetitionsView.fixture;

  /// Tabla elegida (`anual`, `apertura-a`…), si viene en la URL.
  static String? parseTable(Map<String, String> query) => query['tabla'];

  /// URL a reponer cuando el router vuelve a la ubicación del fixture (p. ej.
  /// al volver de un partido o de otra sección): la ubicación del router es
  /// la que abrió la pantalla y no sigue los cambios de competición, fase,
  /// etapa o tabla. Devuelve [target] si [location] es de esta pantalla y no
  /// la tiene; si no, `null`.
  static Uri? urlToRestore(Uri location, Uri? target) {
    if (target == null) return null;
    final segments = location.pathSegments;
    if (segments.isEmpty || '/${segments.first}' != basePath) return null;
    if (segments.length > 2) return null;
    return location.toString() == target.toString() ? null : target;
  }

  /// URL de una tabla.
  static Uri tableUri(int competitionId, Season season, String tableKey) => Uri(
    path: '$basePath/$competitionId',
    queryParameters: {
      'temporada': season.apiValue,
      'vista': 'tabla',
      'tabla': tableKey,
    },
  );

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
