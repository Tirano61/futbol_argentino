/// La forma de un JSON no es la esperada (p. ej. `"events"` no es una lista).
class JsonShapeException implements Exception {
  const JsonShapeException(this.message);

  final String message;

  @override
  String toString() => 'JsonShapeException: $message';
}

/// Extrae listas de registros de las respuestas de TheSportsDB, que siempre
/// tienen la forma `{"<clave>": [ {...}, ... ] | null}`.
abstract final class JsonEnvelope {
  /// Registros bajo [key]. `null` o clave ausente es una respuesta válida sin
  /// datos y devuelve una lista vacía.
  ///
  /// Lanza [JsonShapeException] si el valor no es una lista de objetos.
  static List<Map<String, dynamic>> records(
    Map<String, dynamic> root,
    String key,
  ) {
    final value = root[key];
    if (value == null) return const [];
    if (value is! List) {
      throw JsonShapeException('"$key" no es una lista (${value.runtimeType})');
    }
    return [
      for (final (index, item) in value.indexed)
        if (item is Map<String, dynamic>)
          item
        else
          throw JsonShapeException(
            '$key[$index] no es un objeto JSON (${item.runtimeType})',
          ),
    ];
  }
}
