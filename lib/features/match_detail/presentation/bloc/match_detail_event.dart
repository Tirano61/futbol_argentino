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
