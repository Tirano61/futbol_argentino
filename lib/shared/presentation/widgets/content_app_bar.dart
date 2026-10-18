import 'package:flutter/material.dart';

/// Barra superior alineada con la columna de contenido (Hito E, Fase E7).
///
/// En una pantalla más ancha que [maxWidth] (escritorio de 1920 px) el
/// contenido va centrado; la barra también, así el título, el selector de
/// competición y las acciones quedan sobre el contenido y no en los bordes
/// de la sección. Lo que queda a los costados es el fondo de la pantalla,
/// del mismo color que la barra.
class ContentAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ContentAppBar({super.key, required this.maxWidth, required this.bar});

  final double maxWidth;
  final AppBar bar;

  @override
  Size get preferredSize => bar.preferredSize;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: bar,
    ),
  );
}
