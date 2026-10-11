part of 'match_detail_bloc.dart';

sealed class MatchDetailState extends Equatable {
  const MatchDetailState();

  @override
  List<Object?> get props => [];
}

final class MatchDetailInitial extends MatchDetailState {
  const MatchDetailInitial();
}

final class MatchDetailLoading extends MatchDetailState {
  const MatchDetailLoading();
}

/// Con `result.refreshError` los datos son guardados y la actualización
/// falló.
final class MatchDetailLoaded extends MatchDetailState {
  const MatchDetailLoaded(this.result, {this.isRefreshing = false});

  final DataResult<MatchDetail> result;
  final bool isRefreshing;

  MatchDetailLoaded copyWith({bool? isRefreshing}) => MatchDetailLoaded(
    result,
    isRefreshing: isRefreshing ?? this.isRefreshing,
  );

  @override
  List<Object?> get props => [
    result.data,
    result.origin,
    result.fetchedAt,
    result.refreshError,
    isRefreshing,
  ];
}

final class MatchDetailFailure extends MatchDetailState {
  const MatchDetailFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
