import '../../../core/error/failure.dart';

/// Mensaje para el usuario según el tipo de error.
({String title, String message}) failureMessage(Failure failure) =>
    switch (failure) {
      NetworkFailure(issue: NetworkIssue.timeout) => (
        title: 'La consulta tardó demasiado',
        message: 'TheSportsDB no respondió a tiempo. Probá de nuevo.',
      ),
      NetworkFailure() => (
        title: 'Sin conexión',
        message: 'No se pudo conectar con TheSportsDB. Revisá tu conexión.',
      ),
      RateLimitFailure() => (
        title: 'Demasiadas consultas',
        message:
            'Se superó el límite de TheSportsDB. Probá de nuevo en un minuto.',
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
