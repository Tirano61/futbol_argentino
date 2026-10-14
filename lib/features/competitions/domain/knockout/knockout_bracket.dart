import 'package:equatable/equatable.dart';

import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/entities/team_ref.dart';
import '../../../matches/domain/services/match_grouping.dart';
import '../../../matches/domain/services/tie_outcome.dart';
import '../catalog/competition_catalog.dart';
import '../entities/phase.dart';
import '../entities/season.dart';
import '../services/phase_resolver.dart';

/// Lugar de un partido en el cuadro.
final class BracketSlot extends Equatable {
  const BracketSlot({
    this.match,
    this.outcome,
    this.qualified = const [],
    this.linkedToNext = false,
  });

  /// `null`: la API todavía no tiene el partido (o no lo tiene nunca, como
  /// algunas rondas de la Copa 2025).
  final Match? match;

  /// Quién avanzó, si se sabe (ver [TieOutcome.of]).
  final TieOutcome? outcome;

  /// Sin [match]: los equipos que se sabe que juegan acá (los ganadores de
  /// los partidos anteriores, o el equipo que llegó desde acá a la ronda
  /// siguiente).
  final List<TeamRef> qualified;

  /// Hay evidencia de que el ganador juega el partido de la ronda siguiente
  /// que tiene al lado: comparten un equipo, o la siguiente es la final.
  final bool linkedToNext;

  @override
  List<Object?> get props => [
    match,
    outcome?.winner,
    outcome?.source,
    qualified,
    linkedToNext,
  ];
}

/// Una ronda del cuadro, con sus partidos en el orden de las llaves.
final class BracketRoundView extends Equatable {
  const BracketRoundView({
    required this.label,
    required this.slots,
    this.pairingUnknown = false,
  });

  final String label;
  final List<BracketSlot> slots;

  /// La ronda siguiente no tiene partidos que digan cómo se cruzan: los de
  /// esta ronda van por fecha y sin unir.
  final bool pairingUnknown;

  bool get hasMatches => slots.any((s) => s.match != null);

  @override
  List<Object?> get props => [label, slots, pairingUnknown];
}

/// Cuadro de eliminación directa de una fase (Apertura, Copa…).
final class KnockoutBracket extends Equatable {
  const KnockoutBracket({
    required this.phase,
    required this.rounds,
    this.unplaced = const [],
  });

  final PhaseKey phase;

  /// En orden del torneo; la última es la final.
  final List<BracketRoundView> rounds;

  /// Partidos de la eliminatoria que no se pudieron ubicar (datos
  /// inconsistentes): se muestran aparte, nunca en un lugar inventado.
  final List<Match> unplaced;

  bool get hasMatches => unplaced.isNotEmpty || rounds.any((r) => r.hasMatches);

  @override
  List<Object?> get props => [phase, rounds, unplaced];
}

/// Arma el cuadro con los partidos guardados.
///
/// - Una ronda de la API con varias rondas del cuadro (la 0 de Primera) se
///   reparte por equipo: el primer partido de un equipo en esa ronda es de
///   cuartos, el segundo de semifinales…
/// - El orden de las llaves sale de los equipos: el partido de la ronda
///   anterior que alimenta a uno es el que tiene a alguno de sus equipos.
///   Se arma de la final hacia atrás.
/// - Sin datos de la ronda siguiente, los partidos van por fecha y sin unir
///   (salvo antes de la final: los dos de semifinales la alimentan).
abstract final class KnockoutBracketBuilder {
  static KnockoutBracket build({
    required PhaseKey phase,
    required List<BracketRound> rounds,
    required Iterable<Match> matches,
  }) {
    final unplaced = <Match>[];
    final byRound = [for (final _ in rounds) <Match>[]];

    final byApiRound = <int, List<Match>>{};
    for (final m in MatchGrouping.dedupe(matches)) {
      (byApiRound[m.apiRound] ??= []).add(m);
    }
    for (final MapEntry(key: apiRound, value: inRound) in byApiRound.entries) {
      final indices = [
        for (final (i, r) in rounds.indexed)
          if (r.apiRound == apiRound) i,
      ];
      if (indices.isEmpty) {
        unplaced.addAll(inRound);
      } else if (indices.length == 1) {
        byRound[indices.single].addAll(inRound);
      } else {
        _splitByTeam(inRound, indices, byRound, unplaced);
      }
    }
    for (final (k, inRound) in byRound.indexed) {
      inRound.sort(_byKickoff);
      final expected = rounds[k].matches;
      if (inRound.length > expected) {
        unplaced.addAll(inRound.sublist(expected));
        inRound.removeRange(expected, inRound.length);
      }
    }

    final ordered = _order(rounds, byRound, unplaced);
    final slots = _withOutcomes(ordered, byRound);
    unplaced.sort(_byKickoff);
    return KnockoutBracket(
      phase: phase,
      rounds: [
        for (final (k, r) in rounds.indexed)
          BracketRoundView(
            label: r.label,
            slots: slots[k],
            pairingUnknown:
                k < rounds.length - 1 &&
                slots[k].any((s) => s.match != null && !s.linkedToNext),
          ),
      ],
      unplaced: unplaced,
    );
  }

  /// Cuadros de cada fase de [definition] con los partidos guardados de
  /// [season] (la fase se resuelve ronda por ronda, como en el fixture).
  /// Solo las fases con cuadro y partidos de eliminatoria.
  static Map<PhaseKey, KnockoutBracket> forSeason({
    required CompetitionDefinition definition,
    required Season season,
    required Iterable<Match> matches,
  }) {
    final rounds = definition.bracketRounds;
    if (rounds.isEmpty) return const {};
    final apiRounds = {for (final r in rounds) r.apiRound};
    final unique = MatchGrouping.dedupe(
      matches.where(
        (m) => m.season == season.apiValue && apiRounds.contains(m.apiRound),
      ),
    );
    final resolver = PhaseResolver(definition);
    final byPhase = <PhaseKey, List<Match>>{};
    for (final apiRound in apiRounds) {
      final inRound = [
        for (final m in unique)
          if (m.apiRound == apiRound) m,
      ];
      if (inRound.isEmpty) continue;
      final assigned = resolver.classifyRound(
        season: season,
        apiRound: apiRound,
        matches: inRound,
      );
      for (final m in inRound) {
        final a = assigned[m.id]!;
        if (a.isDetermined && a.stageKind == StageKind.knockout) {
          (byPhase[a.phase] ??= []).add(m);
        }
      }
    }
    return {
      for (final phase in definition.phases)
        if (byPhase[phase] case final phaseMatches?)
          phase: build(phase: phase, rounds: rounds, matches: phaseMatches),
    };
  }

  /// Reparte una ronda de la API entre varias rondas del cuadro: la ronda
  /// de un partido es la cantidad de partidos anteriores de sus equipos en
  /// esa ronda de la API (tienen que coincidir los dos).
  static void _splitByTeam(
    List<Match> inRound,
    List<int> indices,
    List<List<Match>> byRound,
    List<Match> unplaced,
  ) {
    final sorted = [...inRound]..sort(_byKickoff);
    final played = <int, int>{};
    for (final m in sorted) {
      final home = played[m.home.id] ?? 0;
      final away = played[m.away.id] ?? 0;
      played[m.home.id] = home + 1;
      played[m.away.id] = away + 1;
      if (m.kickoff.utc == null || home != away || home >= indices.length) {
        unplaced.add(m);
      } else {
        byRound[indices[home]].add(m);
      }
    }
  }

  /// Orden de las llaves, de la final hacia atrás.
  static List<List<_Slot>> _order(
    List<BracketRound> rounds,
    List<List<Match>> byRound,
    List<Match> unplaced,
  ) {
    final last = rounds.length - 1;
    final result = List<List<_Slot>>.filled(rounds.length, const []);
    result[last] = [
      for (final m in byRound[last]) _Slot(m),
      for (var i = byRound[last].length; i < rounds[last].matches; i++)
        _Slot(null),
    ];
    for (var k = last - 1; k >= 0; k--) {
      final pool = [...byRound[k]];
      final parents = result[k + 1];
      // Antes de la final, los partidos de la ronda la alimentan sí o sí.
      final singleParent = parents.length == 1;
      final children = <_Slot>[];
      final open = <int>[];
      for (final parent in parents) {
        final parentMatch = parent.match;
        if (parentMatch == null) {
          for (final _ in [0, 1]) {
            open.add(children.length);
            children.add(_Slot(null, linked: singleParent));
          }
          continue;
        }
        for (final team in [parentMatch.home, parentMatch.away]) {
          final feeder = pool.where((m) => m.involvesTeam(team.id)).firstOrNull;
          if (feeder != null) pool.remove(feeder);
          children.add(
            _Slot(feeder, linked: true, cameFrom: feeder == null ? team : null),
          );
        }
      }
      for (final i in open) {
        if (pool.isEmpty) break;
        children[i] = _Slot(pool.removeAt(0), linked: singleParent);
      }
      unplaced.addAll(pool);
      result[k] = children;
    }
    return result;
  }

  static List<List<BracketSlot>> _withOutcomes(
    List<List<_Slot>> ordered,
    List<List<Match>> byRound,
  ) {
    final result = <List<BracketSlot>>[];
    for (final (k, round) in ordered.indexed) {
      final later = [for (final r in byRound.skip(k + 1)) ...r];
      final slots = <BracketSlot>[];
      for (final (i, slot) in round.indexed) {
        final m = slot.match;
        final qualified = <TeamRef>[];
        if (m == null) {
          if (slot.cameFrom case final team?) {
            qualified.add(team);
          } else if (k > 0) {
            for (final child in [
              result[k - 1][2 * i],
              result[k - 1][2 * i + 1],
            ]) {
              if (child.linkedToNext && child.outcome != null) {
                qualified.add(child.outcome!.winner);
              }
            }
          }
        }
        slots.add(
          BracketSlot(
            match: m,
            outcome: m == null ? null : TieOutcome.of(m, laterMatches: later),
            qualified: qualified,
            linkedToNext: slot.linked,
          ),
        );
      }
      result.add(slots);
    }
    return result;
  }

  static int _byKickoff(Match a, Match b) {
    final x = a.kickoff.utc;
    final y = b.kickoff.utc;
    if (x != null && y != null && x != y) return x.compareTo(y);
    if (x == null && y != null) return 1;
    if (x != null && y == null) return -1;
    return a.id.compareTo(b.id);
  }
}

final class _Slot {
  _Slot(this.match, {this.linked = false, this.cameFrom});

  final Match? match;
  final bool linked;

  /// Sin partido: el equipo que llegó desde acá a la ronda siguiente.
  final TeamRef? cameFrom;
}
