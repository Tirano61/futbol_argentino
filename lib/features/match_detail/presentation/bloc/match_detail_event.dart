part of 'match_detail_bloc.dart';

sealed class MatchDetailEvent {
  const MatchDetailEvent();
}

final class MatchDetailStarted extends MatchDetailEvent {
  const MatchDetailStarted(this.matchId);

  final int matchId;
}

final class MatchDetailRefreshRequested extends MatchDetailEvent {
  const MatchDetailRefreshRequested();
}

/// Auto-refresco con el partido en vivo (D11): carga normal, que consulta
/// la red solo si venció la vigencia.
final class MatchDetailLiveTick extends MatchDetailEvent {
  const MatchDetailLiveTick();
}
