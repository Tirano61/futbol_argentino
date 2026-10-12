part of 'stored_data_bloc.dart';

sealed class StoredDataState extends Equatable {
  const StoredDataState();

  @override
  List<Object?> get props => [];
}

final class StoredDataLoading extends StoredDataState {
  const StoredDataLoading();
}

final class StoredDataLoaded extends StoredDataState {
  const StoredDataLoaded(
    this.seasons, {
    this.selected = const {},
    this.isDeleting = false,
    this.lastDeleted,
  });

  /// Por competición, la más reciente primero.
  final List<StoredSeason> seasons;

  /// Claves ([StoredSeason.key]) marcadas para borrar.
  final Set<String> selected;
  final bool isDeleting;

  /// Partidos borrados en la última limpieza (para avisarlo).
  final int? lastDeleted;

  List<StoredSeason> get selection => [
    for (final s in seasons)
      if (selected.contains(s.key)) s,
  ];

  StoredDataLoaded copyWith({Set<String>? selected, bool? isDeleting}) =>
      StoredDataLoaded(
        seasons,
        selected: selected ?? this.selected,
        isDeleting: isDeleting ?? this.isDeleting,
        lastDeleted: lastDeleted,
      );

  @override
  List<Object?> get props => [seasons, selected, isDeleting, lastDeleted];
}

/// No se pudo leer o borrar lo guardado (falla de la base local).
final class StoredDataUnavailable extends StoredDataState {
  const StoredDataUnavailable();
}
