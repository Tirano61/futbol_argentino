import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/time/calendar_day.dart';
import '../../../competitions/domain/catalog/competition_catalog.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/domain/services/match_grouping.dart';

/// Partido del Inicio con su contexto de competición.
final class HomeMatch extends Equatable {
  const HomeMatch({
    required this.match,
    required this.competitionName,
    required this.stageLabel,
    this.phaseLabel,
  });

  final Match match;
  final String competitionName;

  /// «Apertura» o «Clausura»; `null` en competiciones de una sola fase o si
  /// la fase no se pudo determinar.
  final String? phaseLabel;

  /// «Fecha 12», «Semifinales»… («Ronda N» sin fase determinada).
  final String stageLabel;

  @override
  List<Object?> get props => [match, competitionName, phaseLabel, stageLabel];
}

/// Lo que el Inicio tiene de una competición.
final class CompetitionFeed extends Equatable {
  const CompetitionFeed({
    required this.competition,
    this.isLoading = true,
    this.matches = const [],
    this.fetchedAt,
    this.error,
  });

  final CompetitionDefinition competition;

  /// Todavía falta alguna consulta de la competición.
  final bool isLoading;

  /// Partidos dentro de la ventana del Inicio (de ayer a 7 días).
  final List<HomeMatch> matches;

  /// Cuándo se obtuvo el dato más viejo que se muestra (UTC); `null` si
  /// todavía no hay datos.
  final DateTime? fetchedAt;

  /// Con datos: la actualización falló y se muestra lo guardado. Sin datos:
  /// no se pudo cargar la competición.
  final Failure? error;

  bool get hasData => fetchedAt != null;
  bool get hasFailed => !isLoading && !hasData && error != null;

  /// Mientras carga: lo nuevo más lo de [previous] que todavía no llegó.
  CompetitionFeed _withPrevious(CompetitionFeed previous) {
    final ids = {for (final m in matches) m.match.id};
    return CompetitionFeed(
      competition: competition,
      matches: [
        ...matches,
        for (final m in previous.matches)
          if (!ids.contains(m.match.id)) m,
      ],
      fetchedAt: fetchedAt ?? previous.fetchedAt,
      error: error ?? previous.error,
    );
  }

  @override
  List<Object?> get props => [
    competition.id,
    isLoading,
    matches,
    fetchedAt,
    error,
  ];
}

/// Partidos de hoy, próximos y recientes de todas las competiciones.
final class HomeFeed extends Equatable {
  const HomeFeed({required this.today, required this.competitions});

  /// Día argentino de la consulta.
  final CalendarDay today;
  final List<CompetitionFeed> competitions;

  /// Partidos de hoy, por hora.
  List<HomeMatch> get todayMatches => _where((day) => day == today);

  /// Partidos de mañana en adelante (hasta 7 días).
  List<HomeMatch> get upcoming => _where((day) => day.isAfter(today));

  /// Partidos de ayer.
  List<HomeMatch> get recent => _where((day) => day.isBefore(today));

  bool get isLoading => competitions.any((c) => c.isLoading);
  bool get hasData => competitions.any((c) => c.hasData);

  /// Competiciones que no se pudieron cargar (sin red y sin datos guardados).
  List<CompetitionDefinition> get failedCompetitions => [
    for (final c in competitions)
      if (c.hasFailed) c.competition,
  ];

  /// Primer error sin datos (para la pantalla de error si no hay nada).
  Failure? get failure =>
      competitions.where((c) => c.hasFailed).map((c) => c.error).firstOrNull;

  /// Dato más viejo que se muestra.
  DateTime? get fetchedAt {
    DateTime? oldest;
    for (final c in competitions) {
      final at = c.fetchedAt;
      if (at != null && (oldest == null || at.isBefore(oldest))) oldest = at;
    }
    return oldest;
  }

  /// Error de actualización de alguna competición que muestra datos
  /// guardados.
  Failure? get refreshError => competitions
      .where((c) => c.hasData && c.error != null)
      .map((c) => c.error)
      .firstOrNull;

  /// Durante un refresco, cada competición que todavía está cargando
  /// conserva lo que mostraba [previous] hasta terminar: la lista no se
  /// vacía ni se achica mientras llegan los datos nuevos.
  HomeFeed carryOver(HomeFeed previous) => HomeFeed(
    today: today,
    competitions: [
      for (final c in competitions)
        switch (previous.competitions
            .where((p) => p.competition.id == c.competition.id)
            .firstOrNull) {
          final p? when c.isLoading => c._withPrevious(p),
          _ => c,
        },
    ],
  );

  List<HomeMatch> _where(bool Function(CalendarDay day) test) => [
    for (final c in competitions)
      for (final m in c.matches)
        if (m.match.kickoff.argentinaDay case final day? when test(day)) m,
  ]..sort((a, b) => MatchGrouping.compare(a.match, b.match));

  @override
  List<Object?> get props => [today, competitions];
}
