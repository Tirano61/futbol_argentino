import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../layout/breakpoints.dart';
import 'content_app_bar.dart';
import 'status_views.dart';

/// Enlace con un identificador que no es un número (`/partidos/abc`). Antes
/// decía «Próximamente», que no correspondía (Fase E7). Por enlace directo
/// no hay a dónde volver: se ofrece el Inicio.
class InvalidLinkPage extends StatelessWidget {
  const InvalidLinkPage({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ContentAppBar(
        maxWidth: Breakpoints.maxNarrowWidth,
        bar: AppBar(title: Text(title)),
      ),
      body: EmptyView(
        icon: icon,
        title: 'Enlace no válido',
        message: message,
        action: FilledButton.tonalIcon(
          onPressed: () => context.go(AppRoutes.home),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Ir al inicio'),
        ),
      ),
    );
  }
}
