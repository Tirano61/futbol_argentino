part of 'team_search_bloc.dart';

/// Resultado de la búsqueda actual.
sealed class TeamSearchResults extends Equatable {
  const TeamSearchResults();

  @override
  List<Object?> get props => [];
}

/// Sin búsqueda.
final class TeamSearchIdle extends TeamSearchResults {
  const TeamSearchIdle();
}

/// Buscando en línea, o esperando el índice (primera vez).
final class TeamSearchSearching extends TeamSearchResults {
  const TeamSearchSearching();
}

final class TeamSearchFound extends TeamSearchResults {
  const TeamSearchFound(this.teams, {this.isOnline = false});

  final List<TeamSummary> teams;

  /// No hubo coincidencias guardadas: vienen de la búsqueda en línea.
  final bool isOnline;

  @override
  List<Object?> get props => [teams, isOnline];
}

final class TeamSearchNoResults extends TeamSearchResults {
  const TeamSearchNoResults({this.onlineFailure});

  /// La búsqueda en línea falló (sin red, 429…).
  final Failure? onlineFailure;

  @override
  List<Object?> get props => [onlineFailure];
}

final class TeamSearchState extends Equatable {
  const TeamSearchState({
    this.query = '',
    this.isIndexing = false,
    this.indexSize = 0,
    this.indexFailure,
    this.results = const TeamSearchIdle(),
  });

  final String query;

  /// Se están descargando los equipos de las competiciones.
  final bool isIndexing;

  /// Equipos guardados en el índice local.
  final int indexSize;

  /// No se pudieron descargar los equipos (se busca con lo guardado).
  final Failure? indexFailure;
  final TeamSearchResults results;

  TeamSearchState copyWith({
    String? query,
    bool? isIndexing,
    int? indexSize,
    Failure? Function()? indexFailure,
    TeamSearchResults? results,
  }) => TeamSearchState(
    query: query ?? this.query,
    isIndexing: isIndexing ?? this.isIndexing,
    indexSize: indexSize ?? this.indexSize,
    indexFailure: indexFailure == null ? this.indexFailure : indexFailure(),
    results: results ?? this.results,
  );

  @override
  List<Object?> get props => [
    query,
    isIndexing,
    indexSize,
    indexFailure,
    results,
  ];
}
