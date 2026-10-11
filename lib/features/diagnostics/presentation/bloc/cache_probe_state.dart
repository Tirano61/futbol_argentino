part of 'cache_probe_bloc.dart';

/// Una emisión del repositorio, o un error sin datos.
final class CacheProbeEntry {
  const CacheProbeEntry({
    required this.run,
    required this.forced,
    required this.receivedAt,
    this.origin,
    this.fetchedAt,
    this.count,
    this.error,
  });

  final int run;
  final bool forced;
  final DateTime receivedAt;

  /// `null` si no hubo datos (error sin caché).
  final DataOrigin? origin;
  final DateTime? fetchedAt;
  final int? count;
  final Failure? error;
}

final class CacheProbeState {
  const CacheProbeState({
    this.entries = const [],
    this.running = false,
    this.runs = 0,
  });

  /// Más reciente primero.
  final List<CacheProbeEntry> entries;
  final bool running;
  final int runs;

  CacheProbeState copyWith({bool? running, int? runs}) => CacheProbeState(
    entries: entries,
    running: running ?? this.running,
    runs: runs ?? this.runs,
  );

  CacheProbeState withEntry(CacheProbeEntry entry) => CacheProbeState(
    entries: [entry, ...entries],
    running: running,
    runs: runs,
  );
}
