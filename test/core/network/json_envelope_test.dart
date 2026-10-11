import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_argentino/core/network/json_envelope.dart';

import '../../helpers/fixtures.dart';

void main() {
  group('JsonEnvelope.records', () {
    test('devuelve los eventos de una respuesta real', () {
      final json = fixtureJson('eventsround_4406_r12_s2026');

      expect(JsonEnvelope.records(json, 'events'), hasLength(30));
    });

    test('"events": null real es una lista vacía', () {
      final json = fixtureJson('eventsround_4406_r17_s2026');

      expect(json['events'], isNull);
      expect(JsonEnvelope.records(json, 'events'), isEmpty);
    });

    test('clave ausente es una lista vacía', () {
      expect(JsonEnvelope.records({}, 'events'), isEmpty);
    });

    test('lanza si el valor no es una lista', () {
      expect(
        () => JsonEnvelope.records({'events': 'x'}, 'events'),
        throwsA(isA<JsonShapeException>()),
      );
    });

    test('lanza si un elemento no es un objeto', () {
      expect(
        () => JsonEnvelope.records({
          'events': [
            {'idEvent': '1'},
            3,
          ],
        }, 'events'),
        throwsA(
          isA<JsonShapeException>().having(
            (e) => e.message,
            'message',
            contains('events[1]'),
          ),
        ),
      );
    });
  });
}
