import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/time/clock.dart';
import '../../domain/entities/stored_season.dart';
import '../../domain/usecases/stored_seasons.dart';

part 'stored_data_event.dart';
part 'stored_data_state.dart';

/// «Datos guardados» de Ajustes: temporadas guardadas y limpieza manual.
/// No hace peticiones.
class StoredDataBloc extends Bloc<StoredDataEvent, StoredDataState> {
  StoredDataBloc({
    required GetStoredSeasons getStoredSeasons,
    required DeleteStoredSeasons deleteStoredSeasons,
    required Clock clock,
  }) : _getStoredSeasons = getStoredSeasons,
       _deleteStoredSeasons = deleteStoredSeasons,
       _clock = clock,
       super(const StoredDataLoading()) {
    on<StoredDataStarted>(_onStarted, transformer: droppable());
    on<StoredDataToggled>(_onToggled);
    on<StoredDataDeleteRequested>(_onDelete, transformer: droppable());
  }

  final GetStoredSeasons _getStoredSeasons;
  final DeleteStoredSeasons _deleteStoredSeasons;
  final Clock _clock;

  Future<void> _onStarted(
    StoredDataStarted event,
    Emitter<StoredDataState> emit,
  ) async {
    try {
      emit(StoredDataLoaded(await _getStoredSeasons(now: _clock.now())));
    } catch (_) {
      emit(const StoredDataUnavailable());
    }
  }

  void _onToggled(StoredDataToggled event, Emitter<StoredDataState> emit) {
    final current = state;
    if (current is! StoredDataLoaded || current.isDeleting) return;
    final season = current.seasons.where((s) => s.key == event.key).firstOrNull;
    if (season == null || !season.canDelete) return;
    final selected = {...current.selected};
    if (!selected.remove(event.key)) selected.add(event.key);
    emit(current.copyWith(selected: selected));
  }

  Future<void> _onDelete(
    StoredDataDeleteRequested event,
    Emitter<StoredDataState> emit,
  ) async {
    final current = state;
    if (current is! StoredDataLoaded || current.selection.isEmpty) return;
    emit(current.copyWith(isDeleting: true));
    try {
      final deleted = await _deleteStoredSeasons(
        current.selection,
        now: _clock.now(),
      );
      emit(
        StoredDataLoaded(
          await _getStoredSeasons(now: _clock.now()),
          lastDeleted: deleted,
        ),
      );
    } catch (_) {
      emit(const StoredDataUnavailable());
    }
  }
}
