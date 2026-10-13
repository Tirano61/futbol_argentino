import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

part 'settings_event.dart';
part 'settings_state.dart';

/// Ajustes de toda la app (se crea una vez, arriba del router): el tema de
/// `MaterialApp` y la pantalla de Ajustes leen este estado.
///
/// Con [initial] (leído antes de abrir la app) arranca ya cargado: así el
/// primer cuadro sale con el tema elegido, sin parpadeo.
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({required SettingsRepository settings, AppSettings? initial})
    : _settings = settings,
      super(
        initial == null ? const SettingsLoading() : SettingsLoaded(initial),
      ) {
    on<SettingsSubscribed>(_onSubscribed, transformer: restartable());
    on<ThemePreferenceChanged>(_onThemeChanged, transformer: sequential());
  }

  final SettingsRepository _settings;

  Future<void> _onSubscribed(
    SettingsSubscribed event,
    Emitter<SettingsState> emit,
  ) => emit.forEach<AppSettings>(
    _settings.watch(),
    onData: SettingsLoaded.new,
    // Si la base falla, se sigue con lo que había (o lo predeterminado).
    onError: (error, stackTrace) {
      debugPrint('Ajustes: no se pudieron leer ($error).');
      return SettingsLoaded(state.settings);
    },
  );

  Future<void> _onThemeChanged(
    ThemePreferenceChanged event,
    Emitter<SettingsState> emit,
  ) async {
    // El estado se actualiza solo por la suscripción.
    try {
      await _settings.saveTheme(event.theme);
    } catch (error) {
      debugPrint('Ajustes: no se pudo guardar el tema ($error).');
    }
  }
}
