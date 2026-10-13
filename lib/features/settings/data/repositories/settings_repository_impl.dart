import 'package:sembast/sembast.dart';

import '../../../../core/storage/local_database.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../models/settings_record.dart';

/// Ajustes en la base local (store `settings`, registro `app`): archivo en
/// Android, IndexedDB en Web.
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._db);

  final Database _db;
  final _record = AppStores.settings.record(SettingsRecord.key);

  @override
  Future<AppSettings> read() async =>
      SettingsRecord.fromMap(await _record.get(_db));

  @override
  Stream<AppSettings> watch() =>
      _record.onSnapshot(_db).map((s) => SettingsRecord.fromMap(s?.value));

  @override
  Future<void> saveTheme(ThemePreference theme) => _db.transaction((txn) async {
    final current = SettingsRecord.fromMap(await _record.get(txn));
    await _record.put(
      txn,
      SettingsRecord.toMap(current.copyWith(theme: theme)),
    );
  });
}
