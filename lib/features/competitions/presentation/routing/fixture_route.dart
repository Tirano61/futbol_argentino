import '../../../../core/time/calendar_month.dart';
import '../../domain/catalog/competition_catalog.dart';
import '../../domain/entities/phase.dart';
import '../../domain/entities/season.dart';
import '../../domain/entities/stage.dart';
import '../bloc/competition_fixture_bloc.dart';

/// Vista de la pantalla de competiciones.
enum CompetitionsView {
  fixture,
  table,
  calendar,
  bracket;

  /// Fixture y Calendario siempre; Tabla y Llaves solo en las competiciones
  /// con tabla o cuadro verificados (una URL con otra vista abre el
  /// Fixture).
  bool isAvailableFor(CompetitionDefinition competition) => switch (this) {
    table => competition.hasStandings,
    bracket => competition.hasBracket,
    fixture || calendar => true,
  };
}

/// URL del fixture: `/competiciones/4406?temporada=2026&fase=clausura&ronda=12`
/// (`&etapa=eliminatoria` en etapas de eliminación; copas internacionales:
/// `fase=previa`, `grupos` o `eliminatorias`). Tablas:
/// `/competiciones/4406?temporada=2026&vista=tabla&tabla=apertura-a`
/// (Nacional: `tabla=zona-a`). Calendario:
/// `/competiciones/4406?temporada=2026&vista=calendario&mes=2026-10`.
/// Llaves: `/competiciones/4406?temporada=2026&vista=llaves&llave=apertura`
/// (la Copa, sin `llave`).
abstract final class FixtureRoute {
  static const basePath = '/competiciones';

  /// Nombre de [phase] en la URL (`fase=` y `llave=`).
  static String phaseName(PhaseKey phase) => switch (phase) {
    PhaseKey.apertura => 'apertura',
    PhaseKey.clausura => 'clausura',
    PhaseKey.regular => 'regular',
    PhaseKey.unica => 'copa',
    PhaseKey.qualifying => 'previa',
    PhaseKey.groups => 'grupos',
    PhaseKey.knockoutStage => 'eliminatorias',
    PhaseKey.undetermined => 'sin-fase',
  };

  /// Fase de un nombre de la URL, o `null` si no es ninguna.
  static PhaseKey? parsePhase(String? name) =>
      PhaseKey.values.where((p) => phaseName(p) == name).firstOrNull;

  /// Evento inicial a partir de la URL. Lo que no se entiende se ignora.
  static FixtureOpened parse({
    String? leagueId,
    Map<String, String> query = const {},
  }) {
    final id = int.tryParse(leagueId ?? '');
    return FixtureOpened(
      competitionId: id != null && CompetitionCatalog.byId(id) != null
          ? id
          : CompetitionCatalog.primeraDivision.id,
      season: Season.tryParse(query['temporada']),
      phase: parsePhase(query['fase']),
      apiRound: int.tryParse(query['ronda'] ?? ''),
      // Sin `etapa`, la primera etapa de esa ronda en la fase
      // (`fase=previa&ronda=1`).
      kind: query['etapa'] == 'eliminatoria' ? StageKind.knockout : null,
    );
  }

  static CompetitionsView parseView(Map<String, String> query) =>
      switch (query['vista']) {
        'tabla' => CompetitionsView.table,
        'calendario' => CompetitionsView.calendar,
        'llaves' => CompetitionsView.bracket,
        _ => CompetitionsView.fixture,
      };

  /// Tabla elegida (`anual`, `apertura-a`…), si viene en la URL.
  static String? parseTable(Map<String, String> query) => query['tabla'];

  /// Torneo del cuadro de llaves (`apertura`), si viene en la URL.
  static PhaseKey? parseBracketPhase(Map<String, String> query) =>
      parsePhase(query['llave']);

  /// Mes del calendario (`2026-10`), si viene en la URL y es válido.
  static CalendarMonth? parseMonth(Map<String, String> query) =>
      CalendarMonth.tryParse(query['mes']);

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

  /// URL de una tabla (sin [tableKey], la primera de la competición).
  static Uri tableUri(int competitionId, Season season, String? tableKey) =>
      Uri(
        path: '$basePath/$competitionId',
        queryParameters: {
          'temporada': season.apiValue,
          'vista': 'tabla',
          'tabla': ?tableKey,
        },
      );

  /// URL del calendario (sin [month], el que corresponde a hoy).
  static Uri calendarUri(
    int competitionId,
    Season season,
    CalendarMonth? month,
  ) => Uri(
    path: '$basePath/$competitionId',
    queryParameters: {
      'temporada': season.apiValue,
      'vista': 'calendario',
      'mes': ?month?.toString(),
    },
  );

  /// URL del cuadro de llaves (sin [phase], el último torneo con
  /// eliminatorias).
  static Uri bracketUri(int competitionId, Season season, PhaseKey? phase) =>
      Uri(
        path: '$basePath/$competitionId',
        queryParameters: {
          'temporada': season.apiValue,
          'vista': 'llaves',
          if (phase != null && phase != PhaseKey.unica)
            'llave': phaseName(phase),
        },
      );

  /// URL de una etapa.
  static Uri uriFor(Stage stage) => Uri(
    path: '$basePath/${stage.competitionId}',
    queryParameters: {
      'temporada': stage.season.apiValue,
      'fase': phaseName(stage.phase),
      'ronda': '${stage.apiRound}',
      if (stage.kind == StageKind.knockout) 'etapa': 'eliminatoria',
    },
  );
}
