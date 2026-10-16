import '../../../matches/domain/entities/match.dart';
import '../catalog/competition_catalog.dart';
import '../entities/phase.dart';
import '../entities/season.dart';
import 'regular_season_matches.dart';
import 'standings_table.dart';
import 'team_stats.dart';
import 'tie_breaker.dart';

/// Tabla de una zona de un torneo (Primera 2026: art. 9/10 y 15/16).
///
/// Filas: los equipos de la zona. Suma los partidos regulares **de ese
/// torneo** de cada uno, interzonales incluidos; Apertura y Clausura nunca
/// se mezclan. El enfrentamiento directo usa solo partidos de ese torneo.
abstract final class ZoneTableBuilder {
  static String keyFor(PhaseKey tournament, String zone) =>
      '${tournament.name}-${zone.toLowerCase()}';

  static StandingsTable build({
    required LeagueZonesWithAnnual format,
    required Season season,
    required PhaseKey tournament,
    required String zone,
    required RegularSeasonMatches matches,
    required int roundsQueried,
  }) => _zoneTable(
    key: keyFor(tournament, zone),
    title: '${tournament.label} ${season.year} · Zona $zone',
    shortTitle: '${tournament.label} · Zona $zone',
    ids: format.zones[tournament]![zone]!,
    tournamentMatches: matches.byTournament[tournament] ?? const [],
    tieBreak: format.zoneTieBreak,
    matches: matches,
    roundsQueried: roundsQueried,
    roundsTotal: format.regularRounds.length,
    rules: [
      'Puntos de las ${format.regularRounds.length} fechas del '
          '${tournament.label}: 3 por ganar y 1 por empatar; los '
          'interzonales suman (${format.zoneArticles[tournament]} del '
          '${format.regulation.name}).',
      StandingsNotes.tieBreak(format.zoneTieBreak),
    ],
  );
}

/// Tabla de una zona de una liga de un solo torneo (Primera Nacional 2026:
/// puntos 3 y 5 del reglamento; art. 112 del Reglamento General de AFA).
///
/// Filas: los equipos de la zona. Suma todos sus partidos regulares de la
/// temporada, interzonales incluidos. El enfrentamiento directo usa los
/// partidos del torneo entre los empatados.
abstract final class LeagueZoneTableBuilder {
  static String keyFor(String zone) => 'zona-${zone.toLowerCase()}';

  static StandingsTable build({
    required LeagueZones format,
    required Season season,
    required String zone,
    required RegularSeasonMatches matches,
    required int roundsQueried,
  }) => _zoneTable(
    key: keyFor(zone),
    title: 'Posiciones ${season.year} · Zona $zone',
    shortTitle: 'Zona $zone',
    ids: format.zones[zone]!,
    tournamentMatches: matches.byTournament[PhaseKey.regular] ?? const [],
    tieBreak: format.tieBreak,
    matches: matches,
    roundsQueried: roundsQueried,
    roundsTotal: format.regularRounds.length,
    rules: [
      'Puntos de las ${format.regularRounds.length} fechas: 3 por ganar y 1 '
          'por empatar; los interzonales también suman en la zona '
          '(${format.tableArticle} del ${format.regulation.name}).',
      StandingsNotes.tieBreak(format.tieBreak, source: format.tieBreakArticle),
      format.relegationNote,
    ],
  );
}

/// Tabla de un grupo de una copa internacional (Manual de Clubes de
/// CONMEBOL, 2.4).
///
/// Filas: los 4 equipos del grupo. Suma sus partidos de la fase de grupos;
/// las fases previas y las eliminatorias que comparten la ronda de la API
/// quedan afuera (las separa `PhaseResolver`).
abstract final class GroupTableBuilder {
  static String keyFor(String group) => 'grupo-${group.toLowerCase()}';

  static StandingsTable build({
    required GroupStage format,
    required Season season,
    required String group,
    required RegularSeasonMatches matches,
    required int roundsQueried,
  }) {
    final once = format.tieBreak.any(
      (c) => c is HeadToHeadCriterion && !c.reapply,
    );
    return _zoneTable(
      key: keyFor(group),
      title: 'Fase de grupos ${season.year} · Grupo $group',
      shortTitle: 'Grupo $group',
      ids: format.groups[group]!,
      tournamentMatches: matches.byTournament[PhaseKey.groups] ?? const [],
      tieBreak: format.tieBreak,
      matches: matches,
      roundsQueried: roundsQueried,
      roundsTotal: format.regularRounds.length,
      rules: [
        'Puntos de las ${format.regularRounds.length} fechas de la fase de '
            'grupos: 3 por ganar y 1 por empatar (${format.pointsArticle} '
            'del ${format.regulation.name}).',
        StandingsNotes.tieBreak(
              format.tieBreak,
              source: format.tieBreakArticle,
            ) +
            (once
                ? ' Los partidos entre los empatados se miran una sola vez: '
                      'los que siguen empatados pasan al criterio siguiente.'
                : ''),
        format.qualificationNote,
      ],
    );
  }
}

/// Suma los partidos de [tournamentMatches] en los que juega alguno de
/// [ids] (los de la otra zona incluidos) y ordena la zona con [tieBreak].
StandingsTable _zoneTable({
  required String key,
  required String title,
  required String shortTitle,
  required Set<int> ids,
  required List<Match> tournamentMatches,
  required List<TieBreakCriterion> tieBreak,
  required RegularSeasonMatches matches,
  required int roundsQueried,
  required int roundsTotal,
  required List<String> rules,
}) {
  final scope = [
    for (final m in tournamentMatches)
      if (ids.contains(m.home.id) || ids.contains(m.away.id)) m,
  ];
  final stats = StatsAccumulator([for (final id in ids) matches.team(id)])
    ..addAll(scope);
  final rows = TieBreaker(
    tieBreak,
  ).rank([for (final id in ids) stats[id]!], matches: tournamentMatches);
  return StandingsTable(
    key: key,
    title: title,
    shortTitle: shortTitle,
    kind: StandingsKind.zone,
    rows: rows,
    coverage: matches.coverage(
      scope: scope,
      roundsQueried: roundsQueried,
      roundsTotal: roundsTotal,
      teamIds: ids,
    ),
    notes: [...rules, StandingsNotes.unofficial],
    sharedNote: rows.any((r) => r.isShared)
        ? StandingsNotes.shared(tieBreak)
        : null,
  );
}

/// Tabla anual (Primera 2026: Tabla General de Posiciones, art. 24).
///
/// Se calcula directamente con los partidos regulares de los dos torneos,
/// cada uno una vez (no suma tablas ni repite interzonales), sin octavos,
/// cuartos, semifinales ni final. No depende de las zonas.
abstract final class AnnualTableBuilder {
  static const key = 'anual';

  static StandingsTable build({
    required LeagueZonesWithAnnual format,
    required Season season,
    required RegularSeasonMatches matches,
    required int roundsQueried,
  }) {
    final scope = matches.all.toList();
    final stats = StatsAccumulator([
      for (final id in {
        for (final m in scope) ...[m.home.id, m.away.id],
      })
        matches.team(id),
    ])..addAll(scope);
    final rows = TieBreaker(format.annualTieBreak).rank(stats.all);
    final withoutHeadToHead = !format.annualTieBreak.any(
      (c) => c is HeadToHeadCriterion,
    );
    return StandingsTable(
      key: key,
      title: 'Tabla Anual ${season.year}',
      shortTitle: 'Tabla Anual ${season.year}',
      kind: StandingsKind.annual,
      rows: rows,
      coverage: matches.coverage(
        scope: scope,
        roundsQueried: roundsQueried,
        roundsTotal: format.regularRounds.length,
      ),
      notes: [
        'Tabla General de Posiciones ${season.year} (${format.annualArticle} '
            'del ${format.regulation.name}): suma los puntos de la fase de '
            'zonas del ${[for (final t in format.tournaments) t.label].join(' y del ')}; '
            'no incluye octavos, cuartos, semifinales ni final.',
        StandingsNotes.tieBreak(format.annualTieBreak) +
            (withoutHeadToHead ? ' Sin partidos entre los empatados.' : ''),
        'Descensos: ante igualdad se juegan partidos de desempate '
            '(art. 24.4); la app no los define.',
        StandingsNotes.unofficial,
      ],
      sharedNote: rows.any((r) => r.isShared)
          ? StandingsNotes.shared(format.annualTieBreak)
          : null,
    );
  }
}

/// Aclaraciones comunes de las tablas.
abstract final class StandingsNotes {
  static const unofficial =
      'Calculada por la app con los partidos de TheSportsDB: no es la tabla '
      'oficial.';

  /// [source]: de dónde salen los criterios, si no es el artículo de la
  /// tabla.
  static String tieBreak(List<TieBreakCriterion> criteria, {String? source}) =>
      'Desempate: ${_join([for (final c in criteria) c.label])}'
      '${source == null ? '' : ' ($source)'}.';

  /// Para los que siguen empatados al llegar a criterios no calculables.
  static String shared(List<TieBreakCriterion> criteria) {
    final missing = [
      for (final c in criteria)
        if (!c.isComputable) c.label,
    ];
    return missing.isEmpty
        ? 'Posición compartida: el reglamento no define más criterios.'
        : 'Posición compartida: se define por ${_join(missing, 'o')} '
              '(no disponible).';
  }

  static String _join(List<String> items, [String conjunction = 'y']) =>
      items.length < 2
      ? items.join()
      : '${items.sublist(0, items.length - 1).join(', ')} $conjunction '
            '${items.last}';
}
