part of 'team_search_bloc.dart';

sealed class TeamSearchEvent {
  const TeamSearchEvent();
}

/// Abre el buscador: carga el índice guardado y lo completa en segundo
/// plano. [initialQuery] viene de la URL (`/equipos?q=`).
final class TeamSearchStarted extends TeamSearchEvent {
  const TeamSearchStarted({this.initialQuery = ''});

  final String initialQuery;
}

/// Eventos que cambian la búsqueda: comparten un handler `restartable`.
sealed class TeamSearchQueryEvent extends TeamSearchEvent {
  const TeamSearchQueryEvent();
}

/// El texto cambió: busca después de una pausa (debounce).
final class TeamSearchQueryChanged extends TeamSearchQueryEvent {
  const TeamSearchQueryChanged(this.query);

  final String query;
}

final class TeamSearchCleared extends TeamSearchQueryEvent {
  const TeamSearchCleared();
}

/// El índice cambió: repite la búsqueda actual sin esperar.
final class _TeamIndexChanged extends TeamSearchQueryEvent {
  const _TeamIndexChanged();
}
