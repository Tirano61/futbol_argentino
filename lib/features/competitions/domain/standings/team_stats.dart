import 'package:equatable/equatable.dart';

import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/entities/team_ref.dart';

/// Estadísticas de un equipo en una tabla: PJ, PG, PE, PP, GF, GC.
final class TeamStats extends Equatable {
  const TeamStats({
    required this.team,
    this.won = 0,
    this.drawn = 0,
    this.lost = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
  });

  final TeamRef team;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;

  int get played => won + drawn + lost;
  int get goalDifference => goalsFor - goalsAgainst;

  /// 3 por partido ganado y 1 por empatado.
  int get points => won * 3 + drawn;

  TeamStats withResult(int scored, int conceded) => TeamStats(
    team: team,
    won: won + (scored > conceded ? 1 : 0),
    drawn: drawn + (scored == conceded ? 1 : 0),
    lost: lost + (scored < conceded ? 1 : 0),
    goalsFor: goalsFor + scored,
    goalsAgainst: goalsAgainst + conceded,
  );

  @override
  List<Object?> get props => [team, won, drawn, lost, goalsFor, goalsAgainst];
}

/// Suma cada partido terminado con resultado **una vez** a cada uno de sus
/// dos equipos (un partido repetido por `idEvent` se ignora).
final class StatsAccumulator {
  /// [teams]: equipos que tienen fila aunque no hayan jugado.
  StatsAccumulator([Iterable<TeamRef> teams = const []])
    : _stats = {for (final t in teams) t.id: TeamStats(team: t)};

  final Map<int, TeamStats> _stats;
  final _counted = <int>{};

  /// El partido cuenta: terminado y con resultado.
  static bool counts(Match m) => m.status.isFinished && m.score != null;

  /// Devuelve si lo sumó (no lo suma si no cuenta o ya estaba).
  bool add(Match m) {
    if (!counts(m) || !_counted.add(m.id)) return false;
    final score = m.score!;
    _record(m.home, score.home, score.away);
    _record(m.away, score.away, score.home);
    return true;
  }

  void addAll(Iterable<Match> matches) => matches.forEach(add);

  void _record(TeamRef team, int scored, int conceded) {
    _stats[team.id] = (_stats[team.id] ?? TeamStats(team: team)).withResult(
      scored,
      conceded,
    );
  }

  /// Partidos sumados.
  int get matchCount => _counted.length;

  TeamStats? operator [](int teamId) => _stats[teamId];

  Iterable<TeamStats> get all => _stats.values;
}
