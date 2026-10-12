import 'package:flutter/material.dart';

import '../../../core/time/argentina_time.dart';

/// Avisa que un refresco manual no consultó la red: los datos se
/// actualizaron hace menos de 30 s (`CacheClass.manualRefreshInterval`).
/// Con [fetchedAt], dice de qué hora son.
void showAlreadyUpToDate(BuildContext context, [DateTime? fetchedAt]) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          fetchedAt == null
              ? 'Ya está actualizado.'
              : 'Ya está actualizado: los datos son de las '
                    '${ArgentinaTime.formatTime(fetchedAt)}.',
        ),
      ),
    );
}
