import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Respuestas reales de TheSportsDB grabadas en `test/fixtures/api/`.
Uint8List fixtureBytes(String name) =>
    File('test/fixtures/api/$name.json').readAsBytesSync();

Map<String, dynamic> fixtureJson(String name) =>
    jsonDecode(utf8.decode(fixtureBytes(name))) as Map<String, dynamic>;

/// Eventos (`"events"`) de una respuesta grabada.
List<Map<String, dynamic>> fixtureEvents(String name) => [
  for (final e in (fixtureJson(name)['events'] as List?) ?? const [])
    e as Map<String, dynamic>,
];

/// Un evento real por `idEvent`.
Map<String, dynamic> fixtureEvent(String name, String idEvent) =>
    fixtureEvents(name).singleWhere((e) => e['idEvent'] == idEvent);
