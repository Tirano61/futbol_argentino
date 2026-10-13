import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../core/cache/cache_class.dart';

/// Auto-refresco con partidos en vivo (D11).
///
/// Mientras la pantalla se ve (`TickerMode`: otra sección del menú o una
/// pantalla encima la apagan) y la app está en primer plano, cada
/// [interval] pregunta [hasLiveMatches] y, si hay alguno, llama a [onTick].
/// [onTick] hace una carga normal: el repositorio solo consulta la red si
/// venció la vigencia `live` (2 min), así que nunca fuerza un refresco.
///
/// Al volver a verse, si hay partidos en vivo, se pone al día enseguida.
class LiveAutoRefresh extends StatefulWidget {
  const LiveAutoRefresh({
    super.key,
    required this.hasLiveMatches,
    required this.onTick,
    required this.child,
  });

  /// Vigencia `live` más un margen: al llegar el aviso, lo descargado en el
  /// aviso anterior ya venció (aunque la respuesta haya tardado unos
  /// segundos) y no se saltea una vuelta.
  static final interval = CacheClass.live.ttl + const Duration(seconds: 5);

  /// Se evalúa en cada aviso: un partido programado pasa a estar en vivo
  /// con solo llegar su hora.
  final bool Function() hasLiveMatches;
  final VoidCallback onTick;
  final Widget child;

  @override
  State<LiveAutoRefresh> createState() => _LiveAutoRefreshState();
}

class _LiveAutoRefreshState extends State<LiveAutoRefresh> {
  ValueListenable<TickerModeData>? _visible;
  late final AppLifecycleListener _lifecycle;
  var _appVisible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _setAppVisible(false),
      onShow: () => _setAppVisible(true),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.getValuesNotifier(context);
    if (visible == _visible) return;
    _visible?.removeListener(_update);
    _visible = visible..addListener(_update);
    _update(catchUp: false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _visible?.removeListener(_update);
    _lifecycle.dispose();
    super.dispose();
  }

  void _setAppVisible(bool visible) {
    _appVisible = visible;
    _update();
  }

  bool get _active => _appVisible && (_visible?.value.enabled ?? false);

  /// Prende o apaga el temporizador según la visibilidad. Al prenderlo
  /// (salvo la primera vez, cuando la pantalla recién carga) se pone al
  /// día.
  void _update({bool catchUp = true}) {
    if (!_active) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null) return;
    _timer = Timer.periodic(LiveAutoRefresh.interval, (_) => _tick());
    if (catchUp) _tick();
  }

  void _tick() {
    if (mounted && widget.hasLiveMatches()) widget.onTick();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
