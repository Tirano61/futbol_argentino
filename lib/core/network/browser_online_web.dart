import 'package:web/web.dart' as web;

/// `navigator.onLine`. Solo `false` es una señal confiable (no hay red);
/// `true` no prueba que haya conexión.
bool browserOnline() => web.window.navigator.onLine;
