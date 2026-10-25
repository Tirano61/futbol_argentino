import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/rate_limit_status.dart';
import '../../core/sync/observed_sync_scheduler.dart';
import '../../core/time/argentina_time.dart';
import '../../core/time/clock.dart';
import '../../shared/presentation/widgets/info_banner.dart';

/// Envuelve toda la app: mientras TheSportsDB tiene pausadas las consultas
/// (HTTP 429), muestra arriba a qué hora se reintenta; mientras una consulta
/// espera 3 s o más por el tope propio de consultas por minuto, lo avisa
/// también. Sin el aviso, las pantallas que esperan parecerían colgadas.
///
/// Fase R3/R3.1 ([RateLimitRecovery]): promete el reintento solo si queda
/// algo pendiente (con un bloqueo persistente, «último intento»); si no
/// queda nada y se abandonó un trabajo en la pausa, dice que la
/// actualización no se completó (la pantalla ofrece «Reintentar»). La hora
/// cambia sola si la pausa se alarga; no hay cuenta regresiva.
///
/// Fase R4 (Web): durante la espera por la sospecha de un 429 oculto por
/// CORS no se afirma un límite (el código HTTP no se conoce): se dice que
/// la consulta falló, las dos causas posibles y, solo si algo la espera, a
/// qué hora se intenta de nuevo.
class RateLimitNotice extends StatefulWidget {
  const RateLimitNotice({super.key, required this.child});

  final Widget child;

  @override
  State<RateLimitNotice> createState() => _RateLimitNoticeState();
}

typedef _Notice = ({
  IconData icon,
  String text,
  String? compactText,
  InfoTone tone,
});

/// Una espera en curso: hasta cuándo dura y el temporizador que la quita.
class _Wait {
  DateTime? until;
  Timer? timer;
}

class _RateLimitNoticeState extends State<RateLimitNotice> {
  late final RateLimitStatus _status = context.read<RateLimitStatus>();
  late final RateLimitRecovery _recovery = context.read<RateLimitRecovery>();
  late final Clock _clock = context.read<Clock>();
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _pause = _Wait();
  final _suspicion = _Wait();
  final _throttle = _Wait();

  @override
  void initState() {
    super.initState();
    _subscriptions
      ..add(_status.pauses.listen((until) => _show(_pause, until)))
      ..add(_status.suspicions.listen((until) => _show(_suspicion, until)))
      ..add(_status.throttles.listen((until) => _show(_throttle, until)))
      // Trabajos que llegan o terminan y abandonos: durante la pausa (o la
      // espera por sospecha) cambia qué se promete; sin ellas no se muestra
      // nada de esto.
      ..add(
        _recovery.changes.listen((_) {
          if (_pause.until != null || _suspicion.until != null) {
            setState(() {});
          }
        }),
      );
    if (_status.pausedUntil case final until?) _show(_pause, until);
    if (_status.suspectedUntil case final until?) _show(_suspicion, until);
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
    _suspicion.timer?.cancel();
    _throttle.timer?.cancel();
    super.dispose();
  }

  /// Si el scheduler abandonó un trabajo en la pausa que termina en
  /// [until]. Una pausa nueva o alargada después vuelve a reintentarse,
  /// salvo que también se abandone un trabajo en ella.
  bool _abandoned(DateTime until) {
    final abandoned = _recovery.abandonedPause;
    return abandoned != null && !abandoned.isBefore(until);
  }

  /// El aviso de la pausa por 429 que termina en [until] (Fase R3.1): solo
  /// promete un reintento si hay algo que va a reintentarse, y solo da por
  /// fallida la actualización si no queda nada pendiente.
  _Notice _pauseNotice(DateTime until) {
    final time = ArgentinaTime.formatTime(until);
    if (_recovery.hasPendingWork) {
      return _recovery.isPersistentBlock
          ? (
              icon: Icons.hourglass_bottom,
              text:
                  'TheSportsDB sigue limitando las consultas. Último intento '
                  'automático a las $time.',
              compactText: 'Límite persistente. Último intento a las $time.',
              tone: InfoTone.warning,
            )
          : (
              icon: Icons.hourglass_top,
              text:
                  'Límite temporal de consultas de TheSportsDB. Se reintentará '
                  'automáticamente a las $time.',
              compactText:
                  'Límite de TheSportsDB. Reintento automático a las $time.',
              tone: InfoTone.warning,
            );
    }
    if (_abandoned(until)) {
      return (
        icon: Icons.sync_problem,
        text:
            'Demasiadas consultas: no fue posible completar la '
            'actualización. Probá de nuevo en unos minutos.',
        compactText: 'Demasiadas consultas. Probá de nuevo en unos minutos.',
        tone: InfoTone.error,
      );
    }
    // Nada espera la pausa: no se promete nada.
    return (
      icon: Icons.hourglass_top,
      text: 'Límite temporal de consultas de TheSportsDB hasta las $time.',
      compactText: null,
      tone: InfoTone.warning,
    );
  }

  /// La espera por la sospecha de un 429 oculto (Fase R4): no lo da por
  /// confirmado y promete otro intento solo si algo lo espera; si no, no
  /// avisa nada (la pantalla muestra su error).
  _Notice? _suspicionNotice(DateTime until) {
    if (!_recovery.hasPendingWork) return null;
    final time = ArgentinaTime.formatTime(until);
    return (
      icon: Icons.sync_problem,
      text:
          'No se pudo consultar TheSportsDB. Puede deberse a la conexión o a '
          'un límite temporal. Se intentará nuevamente a las $time.',
      compactText:
          'No se pudo consultar TheSportsDB. Nuevo intento a las $time.',
      tone: InfoTone.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    // La pausa por 429 manda: es más larga y dice hasta qué hora. Una
    // sospecha no es un 429 confirmado: va después. Mientras dura no sale
    // ninguna consulta, así que no hay espera por el tope.
    final _Notice? notice = switch ((
      _pause.until,
      _suspicion.until,
      _throttle.until,
    )) {
      (final until?, _, _) => _pauseNotice(until),
      (null, final until?, _) => _suspicionNotice(until),
      (null, null, _?) => (
        icon: Icons.hourglass_top,
        text:
            'Muchas consultas seguidas: para no pasar el límite de '
            'TheSportsDB, se sigue en menos de un minuto.',
        compactText:
            'Muchas consultas seguidas: se sigue en menos de un minuto.',
        tone: InfoTone.info,
      ),
      (null, null, null) => null,
    };
    // La estructura no cambia con el aviso: el contenido conserva su
    // estado.
    return Column(
      children: [
        if (notice != null)
          Semantics(
            container: true,
            child: InfoBanner(
              icon: notice.icon,
              text: notice.text,
              compactText: notice.compactText,
              tone: notice.tone,
              band: true,
            ),
          ),
        Expanded(
          // Contenedores propios: la ruta bloquea la semántica de lo pintado
          // antes en su contenedor, y sin esto el aviso no llegaba a los
          // lectores de pantalla (Fase R3).
          child: Semantics(
            container: true,
            child: MediaQuery.removePadding(
              context: context,
              removeTop: notice != null,
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}
