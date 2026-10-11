import 'package:flutter/foundation.dart';

/// Configuración de la app. La clave de TheSportsDB se puede cambiar con
/// `--dart-define=TSDB_API_KEY=...` (por defecto, la clave gratuita `123`).
class AppConfig {
  const AppConfig({
    required this.apiKey,
    required this.enableDiagnostics,
    this.requestTimeout = const Duration(seconds: 15),
    this.maxRequestsPerMinute = 25,
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiKey: String.fromEnvironment('TSDB_API_KEY', defaultValue: '123'),
    // La pantalla de diagnóstico existe en debug, o en cualquier build con
    // `--dart-define=DIAGNOSTICS=true`.
    enableDiagnostics:
        kDebugMode || bool.fromEnvironment('DIAGNOSTICS', defaultValue: false),
  );

  final String apiKey;
  final bool enableDiagnostics;
  final Duration requestTimeout;

  /// Tope propio, por debajo del límite de 30/min de la clave gratuita.
  final int maxRequestsPerMinute;

  Uri get apiBaseUri =>
      Uri.parse('https://www.thesportsdb.com/api/v1/json/$apiKey/');
}
