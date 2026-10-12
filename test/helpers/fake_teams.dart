import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/result/data_result.dart';
import 'package:futbol_argentino/features/matches/domain/entities/team_ref.dart';
import 'package:futbol_argentino/features/teams/data/models/team_dto.dart';
import 'package:futbol_argentino/features/teams/domain/entities/team.dart';
import 'package:futbol_argentino/features/teams/domain/entities/team_summary.dart';
import 'package:futbol_argentino/features/teams/domain/repositories/team_repository.dart';

import 'fakes.dart';
import 'fixture_matches.dart';
import 'fixtures.dart';

/// Equipos reales de la primera etapa 2026 de cada competición, con sus
/// competiciones (como los arma el índice local).
List<TeamSummary> recordedTeamSummaries() {
  final competitions = <int, Set<int>>{};
  final refs = <int, TeamRef>{};
  for (final (name, id) in [
    ('eventsround_4406_r1_s2026', 4406),
    ('eventsround_4616_r1_s2026', 4616),
    ('eventsround_4500_r64_s2026', 4500),
  ]) {
    for (final m in fixtureMatches(name)) {
      for (final t in [m.home, m.away]) {
        refs[t.id] = t;
        (competitions[t.id] ??= {}).add(id);
      }
    }
  }
  return [
    for (final MapEntry(:key, :value) in competitions.entries)
      TeamSummary(team: refs[key]!, competitionIds: value.toList()..sort()),
  ];
}

/// Equipos reales de una respuesta grabada de `lookupteam`/`searchteams`.
List<Team> recordedTeams(String fixture) => [
  for (final t in fixtureJson(fixture)['teams'] as List? ?? const [])
    ?TeamDto.fromJson(t as Map<String, dynamic>).toEntity(),
];

/// - [stored]: índice local.
/// - [online]: respuestas de la búsqueda en línea por texto buscado (sin
///   entrada: lista vacía); [onlineFailure] la hace fallar; [onlineDelay]
///   la demora.
/// - [teams]: `lookupteam` por id; [teamFailure] lo hace fallar.
class FakeTeamRepository implements TeamRepository {
  FakeTeamRepository({
    this.stored = const [],
    this.online = const {},
    this.onlineFailure,
    this.onlineDelay = Duration.zero,
    this.teams = const {},
    this.teamFailure,
  });

  List<TeamSummary> stored;
  final Map<String, List<Team>> online;
  final Failure? onlineFailure;
  final Duration onlineDelay;
  final Map<int, Team> teams;
  final Failure? teamFailure;
  final onlineQueries = <String>[];
  final teamCalls = <({int id, bool force})>[];

  @override
  Future<List<TeamSummary>> storedTeams() async => stored;

  @override
  Future<List<Team>> searchOnline(String query) async {
    onlineQueries.add(query);
    await Future<void>.delayed(onlineDelay);
    if (onlineFailure != null) throw onlineFailure!;
    return online[query] ?? const [];
  }

  @override
  Future<DataResult<Team>> getTeam(
    int teamId, {
    bool forceRefresh = false,
  }) async {
    teamCalls.add((id: teamId, force: forceRefresh));
    if (teamFailure != null) throw teamFailure!;
    final team = teams[teamId];
    if (team == null) throw NotFoundFailure(detail: 'sin equipo $teamId');
    return DataResult(
      data: team,
      origin: DataOrigin.remote,
      fetchedAt: fakeFetchedAt,
    );
  }
}
