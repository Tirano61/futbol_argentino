import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_spacing.dart';

/// Fila de un solo renglón que, si no entra, se desplaza de costado (Hito E,
/// Fase E4). Nunca parte ni achica lo que lleva:
/// - el borde por donde sigue el contenido se esfuma (indicación discreta
///   de que hay más);
/// - [visible] (el elegido) queda a la vista al abrir y cuando cambia;
/// - en Web se arrastra también con el mouse.
class ScrollRow extends StatefulWidget {
  const ScrollRow({
    super.key,
    required this.children,
    this.visible,
    this.spacing = AppSpacing.sm,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;

  /// Índice del hijo que se mantiene a la vista; `null`: ninguno.
  final int? visible;

  final double spacing;
  final EdgeInsetsGeometry padding;

  @override
  State<ScrollRow> createState() => ScrollRowState();
}

class ScrollRowState extends State<ScrollRow> {
  /// Una clave por posición (estable: el elegido no mueve los elementos).
  final _keys = <GlobalKey>[];

  /// Hay contenido antes / después de lo que se ve.
  var _before = false;
  var _after = false;

  /// El borde de cada lado está esfumado (para los tests).
  ({bool before, bool after}) get hints => (before: _before, after: _after);

  @override
  void initState() {
    super.initState();
    _revealLater();
  }

  @override
  void didUpdateWidget(ScrollRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible ||
        oldWidget.children.length != widget.children.length) {
      _revealLater();
    }
  }

  void _revealLater() {
    if (widget.visible == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final index = widget.visible;
      if (!mounted || index == null || index >= _keys.length) return;
      final target = _keys[index].currentContext;
      if (target == null || !target.mounted) return;
      // Lo mínimo para que se vea entero (a la derecha o a la izquierda).
      for (final policy in [
        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ]) {
        Scrollable.ensureVisible(target, alignmentPolicy: policy);
      }
    });
  }

  bool _onMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.horizontal) return false;
    final before = metrics.extentBefore > 0.5;
    final after = metrics.extentAfter > 0.5;
    if (before != _before || after != _after) {
      setState(() {
        _before = before;
        _after = after;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    while (_keys.length < widget.children.length) {
      _keys.add(GlobalKey());
    }
    final row = Row(
      spacing: widget.spacing,
      children: [
        for (final (i, child) in widget.children.indexed)
          KeyedSubtree(key: _keys[i], child: child),
      ],
    );
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onMetrics(n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => n.depth == 0 && _onMetrics(n.metrics),
        // La máscara está siempre (sin esfumado es opaca): agregarla o
        // quitarla recrearía la fila y perdería el desplazamiento.
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => _fade(bounds, _before, _after),
          child: ScrollConfiguration(
            // En Web con mouse también se arrastra (por defecto, solo táctil).
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: widget.padding,
              child: row,
            ),
          ),
        ),
      ),
    );
  }

  /// Máscara: opaca en el medio y transparente en los bordes con más
  /// contenido. Solo cuenta el alfa de los colores.
  static Shader _fade(Rect bounds, bool before, bool after) {
    final width = bounds.width;
    final edge = width <= 0
        ? 0.0
        : (AppSizes.scrollFade / width).clamp(0.0, 0.5).toDouble();
    const opaque = Colors.black;
    const clear = Colors.transparent;
    return LinearGradient(
      colors: [before ? clear : opaque, opaque, opaque, after ? clear : opaque],
      stops: [0, edge, 1 - edge, 1],
    ).createShader(bounds);
  }
}
