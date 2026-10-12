import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/rate_limit_status.dart';
import '../../core/time/argentina_time.dart';
import '../../core/time/clock.dart';

/// Envuelve toda la app: mientras TheSportsDB tiene pausadas las consultas
/// (HTTP 429), muestra arriba hasta qué hora. Sin el aviso, las pantallas
/// que esperan esa pausa parecerían colgadas.
class RateLimitNotice extends StatefulWidget {
  const RateLimitNotice({super.key, required this.child});

  final Widget child;

  @override
  State<RateLimitNotice> createState() => _RateLimitNoticeState();
}

class _RateLimitNoticeState extends State<RateLimitNotice> {
  late final RateLimitStatus _status = context.read<RateLimitStatus>();
  late final Clock _clock = context.read<Clock>();
  StreamSubscription<DateTime>? _subscription;
  Timer? _timer;
  DateTime? _until;

  @override
  void initState() {
    super.initState();
    _subscription = _status.pauses.listen(_show);
    if (_status.pausedUntil case final until?) _show(until);
  }

  void _show(DateTime until) {
    _timer?.cancel();
    final remaining = until.difference(_clock.now());
    if (remaining <= Duration.zero) return;
    setState(() => _until = until);
    _timer = Timer(remaining, () {
      if (mounted) setState(() => _until = null);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final until = _until;
    final colors = Theme.of(context).colorScheme;
    // La estructura no cambia con el aviso: el contenido conserva su
    // estado.
    return Column(
      children: [
        if (until != null)
          Material(
            color: colors.tertiaryContainer,
            child: SafeArea(
              bottom: false,
              child: Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.hourglass_top,
                        color: colors.onTertiaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'TheSportsDB pidió esperar por el límite de '
                          'consultas. Se sigue a las '
                          '${ArgentinaTime.formatTime(until)}.',
                          style: TextStyle(color: colors.onTertiaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: until != null,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
