import '../../../core/error/failure.dart';
import '../../../core/sync/sync_progress.dart';
import 'failure_messages.dart';

/// Textos de una descarga de rondas que se detuvo (Tabla, Calendario,
/// Llaves). Separan tres cosas que antes se mezclaban (Fase E7):
/// - lo **guardado** (cobertura de la tabla o del calendario);
/// - lo **al día** (`SyncProgress.done`: vigente o recién descargado);
/// - que la **actualización falló** (`SyncProgress.failure`).
///
/// Tras un 429 la Tabla decía «No se pudieron consultar todas las fechas
/// (16 de 16)»: el número eran las fechas guardadas, no las actualizadas.
abstract final class SyncTexts {
  /// Avance de la descarga en curso: «Fechas al día: 12 de 16».
  static String running(SyncProgress progress, {required String unit}) =>
      '${unit[0].toUpperCase()}${unit.substring(1)} al día: '
      '${progress.done} de ${progress.total}';

  /// Aviso de una descarga detenida por [failure]. [unit] es «fechas» o
  /// «rondas»; [stored] cuántas hay guardadas (de `progress.total`).
  ///
  /// Si quedaron rondas sin actualizar, se dice cuántas están al día. Si
  /// todas lo están, lo que falló es el refresco manual de las recientes
  /// (las demás ya estaban vigentes): no se informa un «16 de 16» como si
  /// la consulta hubiera salido bien.
  static String stopped(
    SyncProgress progress,
    Failure failure, {
    required String unit,
    int? stored,
  }) {
    final (:title, message: _) = failureMessage(failure);
    final total = progress.total;
    final storedText = stored == null || total == 0
        ? 'Se muestra lo guardado'
        : 'Se muestra lo guardado ($stored de $total $unit)';
    if (total > 0 && progress.done < total) {
      return 'No se pudieron actualizar todas las $unit: ${progress.done} de '
          '$total al día. $storedText. $title.';
    }
    return 'No se pudo actualizar. $storedText. $title.';
  }
}
