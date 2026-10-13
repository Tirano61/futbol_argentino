import 'package:equatable/equatable.dart';

/// Tema elegido en Ajustes.
enum ThemePreference {
  /// Claro u oscuro según el dispositivo (lo de siempre).
  system,
  light,
  dark,
}

/// Preferencias guardadas en este dispositivo.
final class AppSettings extends Equatable {
  const AppSettings({this.theme = ThemePreference.system});

  /// Lo que se usa si nunca se cambió nada.
  static const defaults = AppSettings();

  final ThemePreference theme;

  AppSettings copyWith({ThemePreference? theme}) =>
      AppSettings(theme: theme ?? this.theme);

  @override
  List<Object?> get props => [theme];
}
