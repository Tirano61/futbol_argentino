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
    this.offersContinental = false,
    this.isIndexingContinental = false,
    this.continentalFailure,
    this.results = const TeamSearchIdle(),
  });

  final String query;

  /// Se están descargando los equipos de las competiciones.
  final bool isIndexing;

  /// Equipos guardados en el índice local.
  final int indexSize;

  /// No se pudieron descargar los equipos (se busca con lo guardado).
  final Failure? indexFailure;

  /// Falta bajar los equipos de las copas internacionales: se ofrece si la
  /// búsqueda no encuentra nada guardado.
  final bool offersContinental;
  final bool isIndexingContinental;

  /// No se pudieron bajar los equipos de las copas internacionales.
  final Failure? continentalFailure;
  final TeamSearchResults results;

  TeamSearchState copyWith({
    String? query,
    bool? isIndexing,
    int? indexSize,
    Failure? Function()? indexFailure,
    bool? offersContinental,
    bool? isIndexingContinental,
    Failure? Function()? continentalFailure,
    TeamSearchResults? results,
  }) => TeamSearchState(
    query: query ?? this.query,
    isIndexing: isIndexing ?? this.isIndexing,
    indexSize: indexSize ?? this.indexSize,
    indexFailure: indexFailure == null ? this.indexFailure : indexFailure(),
    offersContinental: offersContinental ?? this.offersContinental,
    isIndexingContinental: isIndexingContinental ?? this.isIndexingContinental,
    continentalFailure: continentalFailure == null
        ? this.continentalFailure
        : continentalFailure(),
    results: results ?? this.results,
  );

  @override
  List<Object?> get props => [
    query,
    isIndexing,
    indexSize,
    indexFailure,
    offersContinental,
    isIndexingContinental,
    continentalFailure,
    results,
  ];
}
