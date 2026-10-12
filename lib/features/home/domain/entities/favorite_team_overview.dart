import 'package:equatable/equatable.dart';

import '../../../favorites/domain/entities/favorite_team.dart';
import 'home_feed.dart';

/// Un equipo favorito en el Inicio: su próximo partido y el último, según
/// los partidos guardados.
final class FavoriteTeamOverview extends Equatable {
  const FavoriteTeamOverview({required this.team, this.next, this.last});

  final FavoriteTeam team;

  /// En juego o el próximo por jugarse.
  final HomeMatch? next;

  /// El último disputado.
  final HomeMatch? last;

  bool get hasMatches => next != null || last != null;

  @override
  List<Object?> get props => [team, next, last];
}
