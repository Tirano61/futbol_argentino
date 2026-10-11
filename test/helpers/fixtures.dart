import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Respuestas reales de TheSportsDB grabadas en `test/fixtures/api/`.
Uint8List fixtureBytes(String name) =>
    File('test/fixtures/api/$name.json').readAsBytesSync();

Map<String, dynamic> fixtureJson(String name) =>
    jsonDecode(utf8.decode(fixtureBytes(name))) as Map<String, dynamic>;
