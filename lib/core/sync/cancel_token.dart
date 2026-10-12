/// Permite a un dueño (un BLoC, una pantalla) cancelar los trabajos de
/// sincronización que pidió y todavía no empezaron.
class CancelToken {
  var _cancelled = false;
  final _listeners = <void Function()>{};

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final listeners = [..._listeners];
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }

  /// [listener] se llama una vez al cancelar (enseguida si ya se canceló).
  void addListener(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }
}

/// El trabajo se descartó antes de empezar: todos los que lo esperaban lo
/// cancelaron.
class SyncCancelled implements Exception {
  const SyncCancelled();

  @override
  String toString() => 'SyncCancelled';
}
