import 'package:futbol_argentino/features/competitions/domain/repositories/competition_repository.dart';
import 'package:futbol_argentino/features/matches/domain/entities/match.dart';

import 'fixture_matches.dart';

/// Punteros reales (`eventsnextleague` / `eventspastleague`) de una
/// competición.
SchedulePointers recordedPointers(int id) => SchedulePointers(
  next: fixtureMatches('eventsnextleague_$id').single,
  last: fixtureMatches('eventspastleague_$id').single,
);

/// Rondas reales que el Inicio necesita el 11/10/2026 (por `apiRound`).
Map<int, List<Match>> recordedRounds() => {
  12: fixtureMatches('eventsround_4406_r12_s2026'),
  13: fixtureMatches('eventsround_4406_r13_s2026'),
  33: fixtureMatches('eventsround_4616_r33_s2026'),
  34: fixtureMatches('eventsround_4616_r34_s2026'),
  125: fixtureMatches('eventsround_4500_r125_s2026'),
  150: fixtureMatches('eventsround_4500_r150_s2026'),
};
