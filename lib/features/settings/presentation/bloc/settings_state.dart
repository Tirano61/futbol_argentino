part of 'settings_bloc.dart';

sealed class SettingsState extends Equatable {
  const SettingsState();

  /// Lo guardado (lo predeterminado mientras carga).
  AppSettings get settings => AppSettings.defaults;

  @override
  List<Object?> get props => [settings];
}

/// Todavía no se leyó la base local.
final class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

final class SettingsLoaded extends SettingsState {
  const SettingsLoaded(this.settings);

  @override
  final AppSettings settings;
}
