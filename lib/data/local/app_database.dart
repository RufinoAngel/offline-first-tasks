import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants.dart';

/// Acceso único a SQLite. Cada isolate (UI / Workmanager) abre su propia
/// conexión al mismo archivo; SQLite serializa las escrituras.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const tasksTable = 'tasks';
  static const metaTable = 'sync_meta';

  Future<Database>? _opening;
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), AppConstants.dbName);
    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tasksTable (
            id         TEXT PRIMARY KEY,               -- UUID v4 del cliente
            title      TEXT NOT NULL,
            is_synced  INTEGER NOT NULL DEFAULT 0,     -- 0 = pendiente, 1 = en la nube
            updated_at TEXT NOT NULL,                  -- ISO-8601 UTC (base de LWW)
            is_deleted INTEGER NOT NULL DEFAULT 0      -- soft delete (tombstone)
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_tasks_pending ON $tasksTable (is_synced)');
        await db.execute('''
          CREATE TABLE $metaTable (
            key   TEXT PRIMARY KEY,                    -- pull_cursor, owner_uid
            value TEXT NOT NULL
          )
        ''');
      },
    );
  }
}
