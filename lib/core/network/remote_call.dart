import '../error/failure.dart';
import 'api_exception.dart';
import 'json_envelope.dart';

/// Ejecuta una consulta remota y traduce sus errores a [Failure]. Los
/// repositorios la usan para que `ApiException` no salga de la capa de
/// datos.
Future<T> remoteCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on ApiException catch (e) {
    throw e.toFailure();
  } on JsonShapeException catch (e) {
    throw FormatFailure(detail: e.message);
  }
}
