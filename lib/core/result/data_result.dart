import '../error/failure.dart';

enum DataOrigin { remote, cache }

/// Datos devueltos por un repositorio, con su procedencia.
///
/// Si [refreshError] no es `null`, los datos son de caché y la actualización
/// falló: la UI los muestra con el aviso «Mostrando datos guardados».
final class DataResult<T> {
  const DataResult({
    required this.data,
    required this.origin,
    required this.fetchedAt,
    this.refreshError,
  });

  final T data;
  final DataOrigin origin;

  /// Cuándo se obtuvieron los datos de la red (UTC).
  final DateTime fetchedAt;
  final Failure? refreshError;

  bool get isFromCache => origin == DataOrigin.cache;
  bool get hasRefreshError => refreshError != null;

  /// Transforma los datos conservando origen, fecha y error de refresco.
  DataResult<R> map<R>(R Function(T data) transform) => DataResult(
    data: transform(data),
    origin: origin,
    fetchedAt: fetchedAt,
    refreshError: refreshError,
  );
}
