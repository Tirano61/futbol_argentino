import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/time/clock.dart';
import '../../domain/entities/home_feed.dart';
import '../../domain/usecases/get_home_feed.dart';

part 'home_event.dart';
part 'home_state.dart';

/// Inicio: partidos de hoy, próximos y recientes.
///
/// `droppable`: mientras hay una carga en curso, otro pedido se descarta
/// (la carga en curso ya trae lo último).
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({required GetHomeFeed getHomeFeed, required Clock clock})
    : _getHomeFeed = getHomeFeed,
      _clock = clock,
      super(const HomeInitial()) {
    on<HomeEvent>(_onEvent, transformer: droppable());
  }

  final GetHomeFeed _getHomeFeed;
  final Clock _clock;

  Future<void> _onEvent(HomeEvent event, Emitter<HomeState> emit) async {
    final previous = switch (state) {
      HomeLoaded(:final feed) => feed,
      _ => null,
    };
    if (previous == null) emit(const HomeLoading());

    await emit.forEach<HomeFeed>(
      _getHomeFeed(
        now: _clock.now(),
        forceRefresh: event is HomeRefreshRequested,
      ),
      onData: (feed) {
        final shown = previous == null ? feed : feed.carryOver(previous);
        if (shown.hasData) return HomeLoaded(shown);
        if (shown.isLoading) return const HomeLoading();
        final failure = shown.failure;
        return failure == null ? HomeLoaded(shown) : HomeFailure(failure);
      },
    );
  }
}
