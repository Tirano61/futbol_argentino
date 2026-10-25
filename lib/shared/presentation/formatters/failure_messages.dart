import '../../../core/error/failure.dart';
import '../../../core/time/argentina_time.dart';

/// Mensaje para el usuario según el tipo de error.
({String title, String message}) failureMessage(Failure failure) =>
    switch (failure) {
      NetworkFailure(issue: NetworkIssue.timeout) => (
        title: 'La consulta tardó demasiado',
        message: 'TheSportsDB no respondió a tiempo. Probá de nuevo.',
      ),
      // Solo en Web: el navegador no dice la causa (un HTTP 429 sin CORS
      // llega igual que un fallo de red). Sin el código HTTP no se afirma
      // ninguna de las dos (Fase R4).
      NetworkFailure(issue: NetworkIssue.possibleCors) => (
        title: 'No se pudo consultar TheSportsDB',
        message:
            'Puede deberse a la conexión o a un límite temporal de '
            'consultas. Probá de nuevo en unos minutos.',
      ),
      NetworkFailure() => (
        title: 'Sin conexión',
        message: 'No se pudo conectar con TheSportsDB. Revisá tu conexión.',
      ),
      // Llega a la pantalla solo cuando el scheduler dejó de reintentar
      // (Fase R2): no se promete otro intento automático. Solo se dice
      // «varios intentos» si los hubo (Fase R3.1).
      RateLimitFailure(
        reason: RateLimitReason.longPause,
        retryAt: final retryAt?,
      ) =>
        (
          title: 'Demasiadas consultas',
          message:
              'TheSportsDB pidió esperar hasta las '
              '${ArgentinaTime.formatTime(retryAt)}. Probá de nuevo después '
              'de esa hora.',
        ),
      RateLimitFailure(reason: RateLimitReason.persistentBlock) => (
        title: 'Demasiadas consultas',
        message:
            'TheSportsDB sigue limitando las consultas. Probá de nuevo en '
            'unos minutos.',
      ),
      RateLimitFailure() => (
        title: 'Demasiadas consultas',
        message:
            'No fue posible completar la actualización después de varios '
            'intentos. Probá de nuevo en unos minutos.',
      ),
      ServerFailure(:final statusCode) => (
        title: 'TheSportsDB no respondió bien',
        message: 'El servidor devolvió el error HTTP $statusCode.',
      ),
      FormatFailure() => (
        title: 'Datos inesperados',
        message: 'TheSportsDB envió datos con un formato que no se reconoce.',
      ),
      NotFoundFailure() => (
        title: 'No se encontraron datos',
        message: 'TheSportsDB no tiene esta información.',
      ),
    };
