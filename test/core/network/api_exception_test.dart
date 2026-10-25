import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/error/failure.dart';
import 'package:futbol_argentino/core/network/api_exception.dart';

void main() {
  final uri = Uri.parse('https://www.thesportsdb.com/api/v1/json/123/x.php');

  Failure map(ApiExceptionType type, {int? statusCode}) => ApiException(
    type: type,
    message: 'detalle real',
    uri: uri,
    statusCode: statusCode,
    elapsed: const Duration(milliseconds: 120),
    rawBody: 'cuerpo',
  ).toFailure();

  test('timeout, conexión y posible CORS son NetworkFailure', () {
    expect(
      map(ApiExceptionType.timeout),
      isA<NetworkFailure>().having(
        (f) => f.issue,
        'issue',
        NetworkIssue.timeout,
      ),
    );
    expect(
      map(ApiExceptionType.connection),
      isA<NetworkFailure>().having(
        (f) => f.issue,
        'issue',
        NetworkIssue.connection,
      ),
    );
    expect(
      map(ApiExceptionType.possibleCors),
      isA<NetworkFailure>().having(
        (f) => f.issue,
        'issue',
        NetworkIssue.possibleCors,
      ),
    );
  });

  test('Fase R4: «sin red» del navegador y sospecha de 429 oculto', () {
    expect(
      map(ApiExceptionType.offline),
      isA<NetworkFailure>()
          .having((f) => f.issue, 'issue', NetworkIssue.offline)
          .having((f) => f.suspectedRateLimit, 'suspected', isFalse),
    );
    expect(
      ApiException(
        type: ApiExceptionType.possibleCors,
        message: 'x',
        uri: uri,
        suspectedRateLimit: true,
      ).toFailure(),
      isA<NetworkFailure>()
          .having((f) => f.issue, 'issue', NetworkIssue.possibleCors)
          .having((f) => f.suspectedRateLimit, 'suspected', isTrue),
    );
    expect(map(ApiExceptionType.possibleCors).limitsQueries, isFalse);
    expect(
      const NetworkFailure(
        issue: NetworkIssue.possibleCors,
        detail: '',
        suspectedRateLimit: true,
      ).limitsQueries,
      isTrue,
    );
    expect(const RateLimitFailure(detail: '').limitsQueries, isTrue);
  });

  test('429 es RateLimitFailure', () {
    expect(
      map(ApiExceptionType.rateLimited, statusCode: 429),
      isA<RateLimitFailure>().having((f) => f.statusCode, 'statusCode', 429),
    );
  });

  test('404 es NotFoundFailure y otros HTTP son ServerFailure', () {
    expect(map(ApiExceptionType.http, statusCode: 404), isA<NotFoundFailure>());
    expect(
      map(ApiExceptionType.http, statusCode: 503),
      isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 503),
    );
  });

  test('formato conserva el detalle, el tiempo y el cuerpo', () {
    expect(
      map(ApiExceptionType.format, statusCode: 200),
      isA<FormatFailure>()
          .having((f) => f.detail, 'detail', 'detalle real')
          .having(
            (f) => f.elapsed,
            'elapsed',
            const Duration(milliseconds: 120),
          )
          .having((f) => f.responseBody, 'responseBody', 'cuerpo'),
    );
  });
}
