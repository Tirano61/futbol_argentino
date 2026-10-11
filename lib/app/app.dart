import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../features/competitions/domain/repositories/competition_repository.dart';
import '../features/diagnostics/domain/repositories/diagnostics_repository.dart';
import '../features/matches/domain/repositories/match_repository.dart';
import 'di/app_dependencies.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class FutbolArgentinoApp extends StatefulWidget {
  const FutbolArgentinoApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<FutbolArgentinoApp> createState() => _FutbolArgentinoAppState();
}

class _FutbolArgentinoAppState extends State<FutbolArgentinoApp> {
  late final GoRouter _router = createAppRouter(
    enableDiagnostics: widget.dependencies.config.enableDiagnostics,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.dependencies;

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppConfig>.value(value: deps.config),
        RepositoryProvider<DiagnosticsRepository>.value(
          value: deps.diagnosticsRepository,
        ),
        RepositoryProvider<MatchRepository>.value(value: deps.matchRepository),
        RepositoryProvider<CompetitionRepository>.value(
          value: deps.competitionRepository,
        ),
      ],
      child: MaterialApp.router(
        title: 'Fútbol Argentino',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        locale: const Locale('es', 'AR'),
        supportedLocales: const [Locale('es', 'AR'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: _router,
      ),
    );
  }
}
