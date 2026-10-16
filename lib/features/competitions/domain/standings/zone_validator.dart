import 'package:equatable/equatable.dart';

import '../catalog/competition_catalog.dart';
import '../entities/phase.dart';
import 'regular_season_matches.dart';

final class ZoneValidation extends Equatable {
  const ZoneValidation(this.issues, {this.invalidZones = const {}});

  /// Qué no coincide entre las zonas del catálogo y los partidos.
  final List<String> issues;

  /// Zonas involucradas en algún problema (para los formatos que validan
  /// cada zona por separado: los grupos de las copas internacionales).
  final Set<String> invalidZones;

  bool get isValid => issues.isEmpty;

  @override
  List<Object?> get props => [issues, invalidZones];
}

/// Controla en tiempo de ejecución que las zonas del catálogo coincidan con
/// los partidos: un equipo sin zona (o en dos), o más partidos contra la
/// otra zona que los interzonales esperados, invalidan las tablas por zona
/// (en una fase de grupos, solo las de los grupos involucrados). La tabla
/// anual no depende de las zonas.
abstract final class ZoneValidator {
  static ZoneValidation validate(
    ZonedStandingsFormat format,
    RegularSeasonMatches matches,
  ) {
    final issues = <String>{};
    final invalid = <String>{};
    final (theZones, noun, otherZone) = switch (format) {
      GroupStage() => ('los grupos', 'grupo', 'otro grupo'),
      _ => ('las zonas', 'zona', 'la otra zona'),
    };
    for (final MapEntry(key: tournament, value: zones)
        in format.zonesByTournament.entries) {
      // Una liga de un solo torneo y la fase de grupos no lo nombran.
      final named =
          tournament != PhaseKey.regular && tournament != PhaseKey.groups;
      final inTournament = named ? ' en el ${tournament.label}' : '';
      final ofTournament = named ? ' del ${tournament.label}' : '';
      final zoneOf = <int, String>{};
      for (final MapEntry(key: zone, value: ids) in zones.entries) {
        for (final id in ids) {
          if (zoneOf[id] case final other? when other != zone) {
            issues.add(
              '${matches.team(id).name} figura en $theZones $other y '
              '$zone$ofTournament.',
            );
            invalid.addAll([other, zone]);
          }
          zoneOf[id] = zone;
        }
      }

      final crossZone = <int, int>{};
      for (final m in matches.byTournament[tournament] ?? const []) {
        final home = zoneOf[m.home.id];
        final away = zoneOf[m.away.id];
        for (final (team, zone, rival) in [
          (m.home, home, away),
          (m.away, away, home),
        ]) {
          if (zone == null) {
            issues.add('${team.name} no tiene $noun$inTournament.');
            if (rival != null) invalid.add(rival);
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
            '${matches.team(id).name} tiene $count '
            '${count == 1 ? 'partido' : 'partidos'} contra $otherZone'
            '$inTournament (se esperan ${format.interzonalsPerTeam}).',
          );
          invalid.add(zoneOf[id]!);
        }
      }
    }
    return ZoneValidation(issues.toList(), invalidZones: invalid);
  }
}
