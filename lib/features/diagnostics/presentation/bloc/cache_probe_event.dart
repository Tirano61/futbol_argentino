part of 'cache_probe_bloc.dart';

sealed class CacheProbeEvent {
  const CacheProbeEvent();
}

final class CacheProbeRequested extends CacheProbeEvent {
  const CacheProbeRequested({this.forceRefresh = false});

  final bool forceRefresh;
}
