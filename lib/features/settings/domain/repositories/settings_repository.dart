import '../entities/app_settings.dart';

/// Preferencias de la app, guardadas solo en este dispositivo (sin red).
///
/// Como los favoritos, no devuelve `DataResult`: los datos son siempre
/// locales y no tienen vigencia.
abstract interface class SettingsRepository {
  /// Lo guardado ([AppSettings.defaults] si no hay nada).
  Future<AppSettings> read();

  /// Emite enseguida y cada vez que cambian.
  Stream<AppSettings> watch();

  Future<void> saveTheme(ThemePreference theme);
}
