import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/sync/sync_progress.dart';
import 'package:futbol_argentino/shared/presentation/formatters/sync_texts.dart';

/// Fase E7: el aviso de una descarga detenida distingue lo guardado, lo al
/// día y la actualización que falló. Antes, tras un 429, la Tabla decía
/// «No se pudieron consultar todas las fechas (16 de 16)»: el 16 eran las
/// fechas guardadas.
void main() {
  const limit = RateLimitFailure(detail: 'HTTP 429');

  test('todas al día pero la actualización falló (el refresco manual de '
      'las recientes): no informa «16 de 16» como un éxito', () {
    const progress = SyncProgress(
      done: 16,
      total: 16,
      isRunning: false,
      failure: limit,
    );
    expect(
      SyncTexts.stopped(progress, limit, unit: 'fechas', stored: 16),
      'No se pudo actualizar. Se muestra lo guardado (16 de 16 fechas). '
      'Demasiadas consultas.',
    );
  });

  test('quedaron fechas sin actualizar: cuántas están al día y cuántas '
      'guardadas, por separado', () {
    const progress = SyncProgress(
      done: 12,
      total: 16,
      isRunning: false,
      failure: limit,
      fetched: 3,
    );
    expect(
      SyncTexts.stopped(progress, limit, unit: 'fechas', stored: 16),
      'No se pudieron actualizar todas las fechas: 12 de 16 al día. Se '
      'muestra lo guardado (16 de 16 fechas). Demasiadas consultas.',
    );
  });

  test('sin el total (falló antes de saber qué revisar) ni lo guardado', () {
    const offline = NetworkFailure(
      issue: NetworkIssue.connection,
      detail: 'sin red',
    );
    const progress = SyncProgress(isRunning: false, failure: offline);
    expect(
      SyncTexts.stopped(progress, offline, unit: 'rondas'),
      'No se pudo actualizar. Se muestra lo guardado. Sin conexión.',
    );
    expect(
      SyncTexts.stopped(
        const SyncProgress(done: 2, total: 5, isRunning: false),
        offline,
        unit: 'rondas',
      ),
      'No se pudieron actualizar todas las rondas: 2 de 5 al día. Se '
      'muestra lo guardado. Sin conexión.',
    );
  });

  test('avance en curso: las rondas al día', () {
    expect(
      SyncTexts.running(const SyncProgress(done: 3, total: 16), unit: 'fechas'),
      'Fechas al día: 3 de 16',
    );
  });
}
