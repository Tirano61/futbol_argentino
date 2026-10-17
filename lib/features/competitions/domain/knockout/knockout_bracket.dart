import 'package:equatable/equatable.dart';

import '../../../matches/domain/entities/knockout_tie.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/entities/team_ref.dart';
import '../../../matches/domain/services/match_grouping.dart';
import '../../../matches/domain/services/tie_outcome.dart';
import '../../../matches/domain/services/tie_pairing.dart';
import '../catalog/competition_catalog.dart';
import '../entities/phase.dart';
import '../entities/season.dart';
import '../services/phase_resolver.dart';

/// Lugar de una llave en el cuadro.
final class BracketSlot extends Equatable {
  const BracketSlot({
    this.tie,
    this.outcome,
    this.qualified = const [],
    this.linkedToNext = false,
  });

  /// `null`: la API todavía no tiene el partido (o no lo tiene nunca, como
  /// algunas rondas de la Copa 2025). Con ida y vuelta, las piernas que
  /// hay.
  final KnockoutTie? tie;

  /// El partido de una llave a un partido (en una serie, la ida).
  Match? get match => tie?.legs.first;

  /// Quién avanzó, si se sabe (ver [TieOutcome.ofTie]).
  final TieOutcome? outcome;

  /// Sin [tie]: los equipos que se sabe que juegan acá (los ganadores de
  /// las llaves anteriores, o el equipo que llegó desde acá a la ronda
  /// siguiente).
  final List<TeamRef> qualified;

  /// Hay evidencia de que el ganador juega la llave de la ronda siguiente
  /// que tiene al lado: comparten un equipo, o la siguiente es la final.
  final bool linkedToNext;

  @override
  List<Object?> get props => [
    tie,
    outcome?.winner,
    outcome?.source,
    qualified,
    linkedToNext,
  ];
}

/// Una ronda del cuadro, con sus llaves en el orden del cuadro.
final class BracketRoundView extends Equatable {
  const BracketRoundView({
    required this.label,
    required this.slots,
    this.legs = 1,
    this.pairingUnknown = false,
  });

  final String label;
  final List<BracketSlot> slots;

  /// 1: a un partido; 2: ida y vuelta.
  final int legs;

  /// La ronda siguiente no tiene partidos que digan cómo se cruzan: las
  /// llaves de esta ronda van por fecha y sin unir.
  final bool pairingUnknown;

  bool get hasMatches => slots.any((s) => s.tie != null);

  @override
  List<Object?> get props => [label, slots, legs, pairingUnknown];
}

/// Ronda de series previa al cuadro (Playoffs de la Sudamericana), para
/// [KnockoutBracketBuilder.build].
typedef PreliminaryRound = ({String label, int legs, List<Match> matches});

/// Cuadro de eliminación directa de una fase (Apertura, Copa…).
final class KnockoutBracket extends Equatable {
  const KnockoutBracket({
    required this.phase,
    required this.rounds,
    this.preliminary = const [],
    this.unplaced = const [],
  });

  final PhaseKey phase;

  /// En orden del torneo; la última es la final.
  final List<BracketRoundView> rounds;

  /// Series previas al cuadro, por fecha y sin unir (Sudamericana: Playoffs
  /// de octavos; sus ganadores juegan los octavos).
  final List<BracketRoundView> preliminary;

  /// Partidos de la eliminatoria que no se pudieron ubicar (datos
  /// inconsistentes): se muestran aparte, nunca en un lugar inventado.
  final List<Match> unplaced;

  bool get hasMatches =>
      unplaced.isNotEmpty ||
      rounds.any((r) => r.hasMatches) ||
      preliminary.any((r) => r.hasMatches);

  @override
  List<Object?> get props => [phase, rounds, preliminary, unplaced];
}

/// Arma el cuadro con los partidos guardados.
///
/// - Una ronda de la API con varias rondas del cuadro (la 0 de Primera) se
///   reparte por equipo: el primer partido de un equipo en esa ronda es de
///   cuartos, el segundo de semifinales…
/// - Con ida y vuelta, las piernas de cada ronda se emparejan en llaves por
///   los dos equipos ([TiePairing]) antes de ordenar.
/// - El orden de las llaves sale de los equipos: la llave de la ronda
///   anterior que alimenta a una es la que tiene a alguno de sus equipos.
///   Se arma de la final hacia atrás.
/// - Sin datos de la ronda siguiente, las llaves van por fecha y sin unir
///   (salvo antes de la final: las dos de semifinales la alimentan).
abstract final class KnockoutBracketBuilder {
  /// [preliminary]: series previas al cuadro (Playoffs de la
  /// Sudamericana), que se muestran como lista.
  static KnockoutBracket build({
    required PhaseKey phase,
    required List<BracketRound> rounds,
    required Iterable<Match> matches,
    List<PreliminaryRound> preliminary = const [],
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
    final tiesByRound = <List<KnockoutTie>>[];
    for (final (k, inRound) in byRound.indexed) {
      final (:ties, :unpaired) = TiePairing.pair(inRound, legs: rounds[k].legs);
      unplaced.addAll(unpaired);
      final expected = rounds[k].matches;
      if (ties.length > expected) {
        for (final extra in ties.sublist(expected)) {
          unplaced.addAll(extra.legs);
        }
        ties.removeRange(expected, ties.length);
      }
      tiesByRound.add(ties);
    }

    final ordered = _order(rounds, tiesByRound, unplaced);
    final slots = _withOutcomes(ordered, tiesByRound);
    final all = [
      for (final ties in tiesByRound)
        for (final t in ties) ...t.legs,
      for (final p in preliminary) ...p.matches,
    ];
    final preliminaryViews = [
      for (final p in preliminary)
        _seriesList(p, laterMatches: all, unplaced: unplaced),
    ];
    unplaced.sort(TiePairing.byKickoff);
    return KnockoutBracket(
      phase: phase,
      rounds: [
        for (final (k, r) in rounds.indexed)
          BracketRoundView(
            label: r.label,
            slots: slots[k],
            legs: r.legs,
            pairingUnknown:
                k < rounds.length - 1 &&
                slots[k].any((s) => s.tie != null && !s.linkedToNext),
          ),
      ],
      preliminary: preliminaryViews,
      unplaced: unplaced,
    );
  }

  /// Cuadros de cada fase de [definition] con los partidos guardados de
  /// [season] (la fase se resuelve ronda por ronda, como en el fixture).
  /// Solo las fases con cuadro y partidos de eliminatoria. En las copas
  /// internacionales, con las series previas (Playoffs de la Sudamericana).
  static Map<PhaseKey, KnockoutBracket> forSeason({
    required CompetitionDefinition definition,
    required Season season,
    required Iterable<Match> matches,
  }) {
    final rounds = definition.bracketRounds;
    if (rounds.isEmpty) return const {};
    final apiRounds = definition.bracketApiRounds(season);
    final preliminaryStages = switch (definition.rules) {
      final ContinentalCupRules r => r.preliminarySeries(season),
      _ => const <ContinentalStage>[],
    };
    final unique = MatchGrouping.dedupe(
      matches.where(
        (m) => m.season == season.apiValue && apiRounds.contains(m.apiRound),
      ),
    );
    final resolver = PhaseResolver(definition);
    final byPhase = <PhaseKey, List<Match>>{};
    final preliminary = <ContinentalStage, List<Match>>{};
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
        if (!a.isDetermined || a.stageKind != StageKind.knockout) continue;
        final stage = preliminaryStages
            .where((s) => s.phase == a.phase && s.apiRound == apiRound)
            .firstOrNull;
        if (stage != null) {
          (preliminary[stage] ??= []).add(m);
        } else {
          (byPhase[a.phase] ??= []).add(m);
        }
      }
    }
    final preliminaryRounds = [
      for (final s in preliminaryStages)
        if (preliminary[s] case final stageMatches?)
          (label: s.label, legs: s.legs, matches: stageMatches),
    ];
    return {
      for (final phase in definition.bracketPhases)
        if (byPhase.containsKey(phase) ||
            (phase == PhaseKey.knockoutStage && preliminaryRounds.isNotEmpty))
          phase: build(
            phase: phase,
            rounds: rounds,
            matches: byPhase[phase] ?? const [],
            preliminary: phase == PhaseKey.knockoutStage
                ? preliminaryRounds
                : const [],
          ),
    };
  }

  /// Series de una ronda previa, por fecha y sin unir. Quién avanzó, con
  /// la evidencia de los partidos posteriores del cuadro.
  static BracketRoundView _seriesList(
    PreliminaryRound round, {
    required List<Match> laterMatches,
    required List<Match> unplaced,
  }) {
    final (:ties, :unpaired) = TiePairing.pair(round.matches, legs: round.legs);
    unplaced.addAll(unpaired);
    return BracketRoundView(
      label: round.label,
      legs: round.legs,
      slots: [
        for (final tie in ties)
          BracketSlot(
            tie: tie,
            outcome: TieOutcome.ofTie(tie, laterMatches: laterMatches),
          ),
      ],
    );
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
    final sorted = [...inRound]..sort(TiePairing.byKickoff);
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
    List<List<KnockoutTie>> byRound,
    List<Match> unplaced,
  ) {
    final last = rounds.length - 1;
    final result = List<List<_Slot>>.filled(rounds.length, const []);
    result[last] = [
      for (final t in byRound[last]) _Slot(t),
      for (var i = byRound[last].length; i < rounds[last].matches; i++)
        _Slot(null),
    ];
    for (var k = last - 1; k >= 0; k--) {
      final pool = [...byRound[k]];
      final parents = result[k + 1];
      // Antes de la final, las llaves de la ronda la alimentan sí o sí.
      final singleParent = parents.length == 1;
      final children = <_Slot>[];
      final open = <int>[];
      for (final parent in parents) {
        final parentTie = parent.tie;
        if (parentTie == null) {
          for (final _ in [0, 1]) {
            open.add(children.length);
            children.add(_Slot(null, linked: singleParent));
          }
          continue;
        }
        for (final team in [parentTie.first, parentTie.second]) {
          final feeder = pool.where((t) => t.involvesTeam(team.id)).firstOrNull;
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
      for (final t in pool) {
        unplaced.addAll(t.legs);
      }
      result[k] = children;
    }
    return result;
  }

  static List<List<BracketSlot>> _withOutcomes(
    List<List<_Slot>> ordered,
    List<List<KnockoutTie>> byRound,
  ) {
    final result = <List<BracketSlot>>[];
    for (final (k, round) in ordered.indexed) {
      final later = [
        for (final ties in byRound.skip(k + 1))
          for (final t in ties) ...t.legs,
      ];
      final slots = <BracketSlot>[];
      for (final (i, slot) in round.indexed) {
        final tie = slot.tie;
        final qualified = <TeamRef>[];
        if (tie == null) {
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
            tie: tie,
            outcome: tie == null
                ? null
                : TieOutcome.ofTie(tie, laterMatches: later),
            qualified: qualified,
            linkedToNext: slot.linked,
          ),
        );
      }
      result.add(slots);
    }
    return result;
  }
}

final class _Slot {
  _Slot(this.tie, {this.linked = false, this.cameFrom});

  final KnockoutTie? tie;
  final bool linked;

  /// Sin llave: el equipo que llegó desde acá a la ronda siguiente.
  final TeamRef? cameFrom;
}
