part of 'competition_fixture_bloc.dart';

/// Contenido de la etapa seleccionada.
sealed class FixtureContent extends Equatable {
  const FixtureContent();

  @override
  List<Object?> get props => [];
}

final class FixtureInitial extends FixtureContent {
  const FixtureInitial();
}

final class FixtureLoading extends FixtureContent {
  const FixtureLoading();
}

/// Hay partidos. Con `refreshError` los datos son guardados y la
/// actualización falló; con `isRefreshing` se está actualizando.
final class FixtureLoaded extends FixtureContent {
  const FixtureLoaded({
    required this.matches,
    required this.origin,
    required this.fetchedAt,
    this.refreshError,
    this.isRefreshing = false,
  });

  final StageMatches matches;
  final DataOrigin origin;
  final DateTime fetchedAt;
  final Failure? refreshError;
  final bool isRefreshing;

  FixtureLoaded copyWith({bool? isRefreshing}) => FixtureLoaded(
    matches: matches,
    origin: origin,
    fetchedAt: fetchedAt,
    refreshError: refreshError,
    isRefreshing: isRefreshing ?? this.isRefreshing,
  );

  @override
  List<Object?> get props => [
    matches.stage,
    matches.matches,
    matches.series,
    origin,
    fetchedAt,
    refreshError,
    isRefreshing,
  ];
}

/// La etapa no tiene partidos (o la temporada no tiene etapas conocidas).
final class FixtureEmpty extends FixtureContent {
  const FixtureEmpty({
    this.fetchedAt,
    this.refreshError,
    this.isRefreshing = false,
  });

  /// Cuándo se obtuvo la ronda vacía (si se consultó).
  final DateTime? fetchedAt;
  final Failure? refreshError;
  final bool isRefreshing;

  FixtureEmpty copyWith({bool? isRefreshing}) => FixtureEmpty(
    fetchedAt: fetchedAt,
    refreshError: refreshError,
    isRefreshing: isRefreshing ?? this.isRefreshing,
  );

  @override
  List<Object?> get props => [fetchedAt, refreshError, isRefreshing];
}

/// Error sin datos guardados.
final class FixtureFailure extends FixtureContent {
  const FixtureFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

final class CompetitionFixtureState extends Equatable {
  const CompetitionFixtureState({
    this.definition,
    this.seasons = const [],
    this.season,
    this.phases = const [],
    this.stages = const [],
    this.stage,
    this.undeterminedInRound = 0,
    this.content = const FixtureInitial(),
  });

  final CompetitionDefinition? definition;
  final List<Season> seasons;
  final Season? season;

  /// Fases ofrecidas (incluye «Sin fase determinada» solo si está elegida).
  final List<PhaseKey> phases;
  final List<Stage> stages;
  final Stage? stage;

  /// Partidos de la ronda actual sin fase determinada.
  final int undeterminedInRound;
  final FixtureContent content;

  PhaseKey? get phase => stage?.phase;

  bool get isRefreshing => switch (content) {
    FixtureLoading() => true,
    FixtureLoaded(:final isRefreshing) => isRefreshing,
    FixtureEmpty(:final isRefreshing) => isRefreshing,
    _ => false,
  };

  bool get hasPrevious =>
      stage != null && RoundNavigator.previous(stages, stage!) != null;
  bool get hasNext =>
      stage != null && RoundNavigator.next(stages, stage!) != null;

  CompetitionFixtureState copyWith({
    CompetitionDefinition? definition,
    List<Season>? seasons,
    Season? season,
    List<PhaseKey>? phases,
    List<Stage>? stages,
    Stage? stage,
    int? undeterminedInRound,
    FixtureContent? content,
  }) => CompetitionFixtureState(
    definition: definition ?? this.definition,
    seasons: seasons ?? this.seasons,
    season: season ?? this.season,
    phases: phases ?? this.phases,
    stages: stages ?? this.stages,
    stage: stage ?? this.stage,
    undeterminedInRound: undeterminedInRound ?? this.undeterminedInRound,
    content: content ?? this.content,
  );

  @override
  List<Object?> get props => [
    definition?.id,
    seasons,
    season,
    phases,
    stages,
    stage,
    undeterminedInRound,
    content,
  ];
}
