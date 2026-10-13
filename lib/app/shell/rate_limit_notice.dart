import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/rate_limit_status.dart';
import '../../core/time/argentina_time.dart';
import '../../core/time/clock.dart';

/// Envuelve toda la app: mientras TheSportsDB tiene pausadas las consultas
/// (HTTP 429), muestra arriba hasta qué hora; mientras una consulta espera
/// 3 s o más por el tope propio de consultas por minuto, lo avisa también.
/// Sin el aviso, las pantallas que esperan parecerían colgadas.
class RateLimitNotice extends StatefulWidget {
  const RateLimitNotice({super.key, required this.child});

  final Widget child;

  @override
  State<RateLimitNotice> createState() => _RateLimitNoticeState();
}

/// Una espera en curso: hasta cuándo dura y el temporizador que la quita.
class _Wait {
  DateTime? until;
  Timer? timer;
}

class _RateLimitNoticeState extends State<RateLimitNotice> {
  late final RateLimitStatus _status = context.read<RateLimitStatus>();
  late final Clock _clock = context.read<Clock>();
  final _subscriptions = <StreamSubscription<DateTime>>[];
  final _pause = _Wait();
  final _throttle = _Wait();

  @override
  void initState() {
    super.initState();
    _subscriptions
      ..add(_status.pauses.listen((until) => _show(_pause, until)))
      ..add(_status.throttles.listen((until) => _show(_throttle, until)));
    if (_status.pausedUntil case final until?) _show(_pause, until);
    if (_status.throttledUntil case final until?) _show(_throttle, until);
  }

  void _show(_Wait wait, DateTime until) {
    final remaining = until.difference(_clock.now());
    if (remaining <= Duration.zero) return;
    wait.timer?.cancel();
    setState(() => wait.until = until);
    wait.timer = Timer(remaining, () {
      if (mounted) setState(() => wait.until = null);
    });
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _pause.timer?.cancel();
    _throttle.timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // La pausa por 429 manda: es más larga y dice hasta qué hora.
    final notice = switch ((_pause.until, _throttle.until)) {
      (final until?, _) => (
        text:
            'TheSportsDB pidió esperar por el límite de consultas. Se sigue '
            'a las ${ArgentinaTime.formatTime(until)}.',
        background: colors.tertiaryContainer,
        foreground: colors.onTertiaryContainer,
      ),
      (null, _?) => (
        text:
            'Muchas consultas seguidas: para no pasar el límite de '
            'TheSportsDB, se sigue en menos de un minuto.',
        background: colors.secondaryContainer,
        foreground: colors.onSecondaryContainer,
      ),
      (null, null) => null,
    };
    // La estructura no cambia con el aviso: el contenido conserva su
    // estado.
    return Column(
      children: [
        if (notice != null)
          Material(
            color: notice.background,
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
                      Icon(Icons.hourglass_top, color: notice.foreground),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          notice.text,
                          style: TextStyle(color: notice.foreground),
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
            removeTop: notice != null,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
