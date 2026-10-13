part of 'settings_bloc.dart';

sealed class SettingsEvent {
  const SettingsEvent();
}

/// Empieza a seguir los ajustes guardados (al abrir la app).
final class SettingsSubscribed extends SettingsEvent {
  const SettingsSubscribed();
}

/// Guarda el tema elegido.
final class ThemePreferenceChanged extends SettingsEvent {
  const ThemePreferenceChanged(this.theme);

  final ThemePreference theme;
}
