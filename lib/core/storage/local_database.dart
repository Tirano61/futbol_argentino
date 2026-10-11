import 'package:flutter/foundation.dart';
import 'package:sembast/sembast_memory.dart';

import 'database_opener_io.dart'
    if (dart.library.js_interop) 'database_opener_web.dart'
    as opener;

/// Base local de la app: un archivo en Android (documentos de la app) e
/// IndexedDB en Web. Es la caché de partidos, competiciones, metadatos de
/// consultas y, más adelante, favoritos.
abstract final class LocalDatabase {
  static const fileName = 'futbol_argentino.db';

  static Future<Database> open() => opener.openAppDatabase(fileName);

  /// Abre la base; si el almacenamiento no está disponible (p. ej. Web en
  /// modo privado con IndexedDB bloqueado) usa una base en memoria: la app
  /// funciona, pero sin datos guardados entre sesiones.
  static Future<Database> openOrMemory() async {
    try {
      return await open();
    } catch (e) {
      debugPrint('No se pudo abrir la base local ($e): se usa memoria.');
      return newDatabaseFactoryMemory().openDatabase(fileName);
    }
  }
}

/// Stores (tablas) de la base.
abstract final class AppStores {
  /// Partidos por `idEvent`.
  static final events = intMapStoreFactory.store('events');

  /// Competiciones por `idLeague`.
  static final competitions = intMapStoreFactory.store('competitions');

  /// Próximo/último partido por `idLeague`.
  static final schedulePointers = intMapStoreFactory.store('schedule_pointers');

  /// Metadatos de consultas por clave (`round:4406:2026:12`…).
  static final queryMeta = stringMapStoreFactory.store('query_meta');
}
