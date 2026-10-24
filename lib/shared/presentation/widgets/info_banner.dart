import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../layout/text_measure.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Tono de un aviso: decide el ícono por defecto y su color.
enum InfoTone {
  /// Información neutra (lo guardado, qué falta consultar).
  info,

  /// Datos incompletos o sin verificar, esperas.
  warning,

  /// No se pudo actualizar: se muestra lo guardado.
  offline,

  /// No se pudo cargar algo.
  error,
}

/// Aviso dentro de una vista (zonas sin verificar, descarga incompleta,
/// datos guardados…), con una acción opcional. Se anuncia a los lectores de
/// pantalla.
///
/// Todos los avisos de la app usan este widget (Hito E, §4.4): fondo
/// `surfaceContainerHigh` y el ícono del color del tono, así ninguno queda
/// fuera de la marca.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    this.icon,
    required this.text,
    this.action,
    this.tone = InfoTone.info,
    this.band = false,
    this.compactText,
  }) : assert(
         compactText == null || action == null,
         'La versión corta se elige midiendo el texto sin acción.',
       );

  /// Renglones de [text] a partir de los que se muestra [compactText].
  static const compactAfterLines = 4;

  /// Si es `null`, el del [tone].
  final IconData? icon;
  final String text;
  final Widget? action;
  final InfoTone tone;

  /// Franja a todo el ancho y sin bordes redondeados, que cubre también la
  /// barra de estado (el aviso de límite de consultas, arriba de la app).
  final bool band;

  /// Versión más corta de [text], para cuando [text] ocupa más de
  /// [compactAfterLines] renglones (texto grande en un teléfono): el aviso
  /// no tapa media pantalla. Los lectores de pantalla leen siempre [text].
  final String? compactText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final palette = AppPalette.of(context);
    final (defaultIcon, iconColor) = switch (tone) {
      InfoTone.info => (Icons.info_outline, colors.primary),
      InfoTone.warning => (Icons.warning_amber, palette.warning),
      InfoTone.offline => (Icons.cloud_off, colors.onSurfaceVariant),
      InfoTone.error => (Icons.error_outline, colors.error),
    };

    final style = theme.textTheme.bannerMessage.copyWith(
      color: colors.onSurface,
    );
    final compactText = this.compactText;
    final message = Row(
      children: [
        Icon(icon ?? defaultIcon, color: iconColor, size: AppSizes.bannerIcon),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: compactText == null
              ? Text(text, style: style)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final measure = TextMeasure.of(context);
                    final width = constraints.maxWidth;
                    final fits =
                        measure.height(text, style, width) <=
                        measure.height(
                          text,
                          style,
                          width,
                          maxLines: compactAfterLines,
                        );
                    return Text(
                      fits ? text : compactText,
                      semanticsLabel: fits ? null : text,
                      style: style,
                    );
                  },
                ),
        ),
      ],
    );
    final side = band ? AppSpacing.lg : AppSpacing.md;
    final action = this.action;
    Widget content = Padding(
      padding: EdgeInsets.fromLTRB(
        side,
        AppSpacing.sm,
        action == null ? side : AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: action == null
          ? message
          : _MessageWithAction(
              // Al lado del texto solo si le deja unas 12 letras por
              // renglón; si no (texto grande en un teléfono), debajo.
              minMessageWidth:
                  AppSizes.bannerIcon +
                  AppSpacing.md +
                  12 *
                      MediaQuery.textScalerOf(
                        context,
                      ).scale(theme.textTheme.bannerMessage.fontSize!),
              children: [message, action],
            ),
    );
    if (band) content = SafeArea(bottom: false, child: content);

    return Semantics(
      liveRegion: true,
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: band ? null : AppRadius.controlAll,
        child: content,
      ),
    );
  }
}

/// El mensaje y su acción: la acción a la derecha si al mensaje le queda
/// al menos [minMessageWidth]; si no, debajo y alineada al final. Así, con
/// el texto al 200 %, el aviso no queda en una columna angosta (el de
/// «Completar» del Calendario ocupaba media pantalla; Fase E7).
class _MessageWithAction extends MultiChildRenderObjectWidget {
  const _MessageWithAction({
    required this.minMessageWidth,
    required super.children,
  });

  final double minMessageWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMessageWithAction(minMessageWidth);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMessageWithAction renderObject,
  ) => renderObject.minMessageWidth = minMessageWidth;
}

class _ActionParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderMessageWithAction extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ActionParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ActionParentData> {
  _RenderMessageWithAction(this._minMessageWidth);

  double _minMessageWidth;
  set minMessageWidth(double value) {
    if (value == _minMessageWidth) return;
    _minMessageWidth = value;
    markNeedsLayout();
  }

  RenderBox get _message => firstChild!;
  RenderBox get _action => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ActionParentData) {
      child.parentData = _ActionParentData();
    }
  }

  /// Si la acción va al lado del mensaje con este ancho.
  bool _beside(double width, double actionWidth) =>
      width - actionWidth >= _minMessageWidth;

  Size _layout(BoxConstraints constraints, {required bool dry}) {
    final width = constraints.maxWidth;
    Size measure(RenderBox child, BoxConstraints c) {
      if (dry) return child.getDryLayout(c);
      child.layout(c, parentUsesSize: true);
      return child.size;
    }

    final action = measure(_action, BoxConstraints(maxWidth: width));
    if (_beside(width, action.width)) {
      final message = measure(
        _message,
        BoxConstraints.tightFor(width: width - action.width),
      );
      final height = math.max(message.height, action.height);
      if (!dry) {
        _offset(_message, Offset(0, (height - message.height) / 2));
        _offset(
          _action,
          Offset(width - action.width, (height - action.height) / 2),
        );
      }
      return constraints.constrain(Size(width, height));
    }
    final message = measure(_message, BoxConstraints.tightFor(width: width));
    if (!dry) {
      _offset(_message, Offset.zero);
      _offset(_action, Offset(width - action.width, message.height));
    }
    return constraints.constrain(Size(width, message.height + action.height));
  }

  static void _offset(RenderBox child, Offset offset) =>
      (child.parentData! as _ActionParentData).offset = offset;

  @override
  void performLayout() => size = _layout(constraints, dry: false);

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, dry: true);

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _message.getMinIntrinsicWidth(height),
    _action.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _message.getMaxIntrinsicWidth(height) +
      _action.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _layout(BoxConstraints(maxWidth: width), dry: true).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
