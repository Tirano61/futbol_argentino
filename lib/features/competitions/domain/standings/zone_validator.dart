import 'package:equatable/equatable.dart';

import '../catalog/competition_catalog.dart';
import '../entities/phase.dart';
import 'regular_season_matches.dart';

final class ZoneValidation extends Equatable {
  const ZoneValidation(this.issues);

  /// Qué no coincide entre las zonas del catálogo y los partidos.
  final List<String> issues;

  bool get isValid => issues.isEmpty;

  @override
  List<Object?> get props => [issues];
}

/// Controla en tiempo de ejecución que las zonas del catálogo coincidan con
/// los partidos: un equipo sin zona (o en dos), o más partidos contra la
/// otra zona que los interzonales esperados, invalidan las tablas por zona.
/// La tabla anual no depende de las zonas.
abstract final class ZoneValidator {
  static ZoneValidation validate(
    ZonedStandingsFormat format,
    RegularSeasonMatches matches,
  ) {
    final issues = <String>{};
    for (final MapEntry(key: tournament, value: zones)
        in format.zonesByTournament.entries) {
      // Una liga de un solo torneo no lo nombra.
      final inTournament = tournament == PhaseKey.regular
          ? ''
          : ' en el ${tournament.label}';
      final ofTournament = tournament == PhaseKey.regular
          ? ''
          : ' del ${tournament.label}';
      final zoneOf = <int, String>{};
      for (final MapEntry(key: zone, value: ids) in zones.entries) {
        for (final id in ids) {
          if (zoneOf[id] case final other? when other != zone) {
            issues.add(
              '${matches.team(id).name} figura en las zonas $other y '
              '$zone$ofTournament.',
            );
          }
          zoneOf[id] = zone;
        }
      }

      final crossZone = <int, int>{};
      for (final m in matches.byTournament[tournament] ?? const []) {
        final home = zoneOf[m.home.id];
        final away = zoneOf[m.away.id];
        for (final (team, zone) in [(m.home, home), (m.away, away)]) {
          if (zone == null) {
            issues.add('${team.name} no tiene zona$inTournament.');
          }
        }
        if (home != null && away != null && home != away) {
          crossZone.update(m.home.id, (n) => n + 1, ifAbsent: () => 1);
          crossZone.update(m.away.id, (n) => n + 1, ifAbsent: () => 1);
        }
      }
      for (final MapEntry(key: id, value: count) in crossZone.entries) {
        if (count > format.interzonalsPerTeam) {
          issues.add(
            '${matches.team(id).name} tiene $count partidos contra la otra '
            'zona$inTournament (se esperan ${format.interzonalsPerTeam}).',
          );
        }
      }
    }
    return ZoneValidation(issues.toList());
  }
}
