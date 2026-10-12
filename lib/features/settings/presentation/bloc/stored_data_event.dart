part of 'stored_data_bloc.dart';

sealed class StoredDataEvent {
  const StoredDataEvent();
}

/// Lee las temporadas guardadas.
final class StoredDataStarted extends StoredDataEvent {
  const StoredDataStarted();
}

/// Marca o desmarca una temporada para borrar ([StoredSeason.key]). Las
/// que no se pueden borrar se ignoran.
final class StoredDataToggled extends StoredDataEvent {
  const StoredDataToggled(this.key);

  final String key;
}

/// Borra las temporadas marcadas (ya confirmado por el usuario).
final class StoredDataDeleteRequested extends StoredDataEvent {
  const StoredDataDeleteRequested();
}
