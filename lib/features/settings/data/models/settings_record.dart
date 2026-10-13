import '../../domain/entities/app_settings.dart';

/// Forma en que se guardan las [AppSettings] en la base local (store
/// `settings`, un solo registro).
abstract final class SettingsRecord {
  static const schemaVersion = 1;

  /// Clave del único registro del store.
  static const key = 'app';

  static Map<String, Object?> toMap(AppSettings s) => {
    'v': schemaVersion,
    'theme': s.theme.name,
  };

  /// Un valor desconocido (o ausente) vuelve al predeterminado.
  static AppSettings fromMap(Map<String, Object?>? map) {
    final theme = map?['theme'];
    return AppSettings(
      theme: ThemePreference.values.firstWhere(
        (t) => t.name == theme,
        orElse: () => AppSettings.defaults.theme,
      ),
    );
  }
}
