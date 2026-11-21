import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/time_utils.dart';
import '../../models/task.dart';
import '../../sync/merge_resolver.dart';
import 'app_database.dart';

/// Capa local: ÚNICA fuente de verdad para la UI.
class TaskLocalDataSource {
  TaskLocalDataSource(this._appDb);

  final AppDatabase _appDb;
  static const _uuid = Uuid();
  static const _kCursor = 'pull_cursor';
  static const _kOwner = 'owner_uid';

  /// Se emite un evento cada vez que cambia la tabla => UI reactiva.
  final StreamController<void> _changes = StreamController<void>.broadcast();

  // ───────────────────────── Streams reactivos ──────────────────────────
  Stream<List<Task>> watchVisible() => _watch(getVisible);
  Stream<int> watchPendingCount() => _watch(pendingCount);

  Stream<T> _watch<T>(Future<T> Function() query) {
    late final StreamController<T> controller;
    StreamSubscription<void>? sub;
    var seq = 0;

    Future<void> emit() async {
      final mine = ++seq;
      try {
        final value = await query();
        // Descarta respuestas viejas que llegan fuera de orden.
        if (mine == seq && !controller.isClosed) controller.add(value);
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        sub = _changes.stream.listen((_) => emit());
        emit();
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  /// Útil cuando OTRO isolate (Workmanager) modificó el archivo .db.
  void notifyExternalChange() => _changes.add(null);

  // ───────────────────────── Escritura local inmediata ───────────────────
  /// Guarda PRIMERO en disco con `is_synced = 0` y `updated_at = ahora`.
  /// No espera a la red => latencia percibida ≈ 0 ms.
  Future<Task> saveLocal(Task task) async {
    final db = await _appDb.database;
    var ts = nowUtc();
    // updated_at estrictamente creciente por registro (aunque el reloj retroceda).
    if (!ts.isAfter(task.updatedAt)) {
      ts = task.updatedAt.add(const Duration(milliseconds: 1));
    }
    final stamped = task.copyWith(isSynced: false, updatedAt: ts);
    await db.insert(
      AppDatabase.tasksTable,
      stamped.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _changes.add(null);
    return stamped;
  }

  Future<Task> create(String title) => saveLocal(
        Task(id: _uuid.v4(), title: title.trim(), updatedAt: nowUtc()),
      );

  Future<void> updateTitle(String id, String title) async {
    final current = await getById(id);
    if (current == null || current.isDeleted) return;
    await saveLocal(current.copyWith(title: title.trim()));
  }

  /// Soft delete: NO se borra la fila; se marca y se sincroniza como cambio.
  Future<void> softDelete(String id) async {
    final current = await getById(id);
    if (current == null || current.isDeleted) return;
    await saveLocal(current.copyWith(isDeleted: true));
  }

  // ───────────────────────── Lecturas ───────────────────────────────────
  Future<Task?> getById(String id) async {
    final db = await _appDb.database;
    final rows = await db.query(AppDatabase.tasksTable,
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Task.fromMap(rows.first);
  }

  Future<List<Task>> getVisible() async {
    final db = await _appDb.database;
    final rows = await db.query(AppDatabase.tasksTable,
        where: 'is_deleted = 0', orderBy: 'updated_at DESC');
    return rows.map(Task.fromMap).toList();
  }

  /// Incluye tombstones. Solo para evidencias/depuración.
  Future<List<Task>> dumpAll() async {
    final db = await _appDb.database;
    final rows =
        await db.query(AppDatabase.tasksTable, orderBy: 'updated_at DESC');
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> getPending() async {
    final db = await _appDb.database;
    final rows = await db.query(AppDatabase.tasksTable,
        where: 'is_synced = 0', orderBy: 'updated_at ASC');
    return rows.map(Task.fromMap).toList();
  }

  Future<int> pendingCount() async {
    final db = await _appDb.database;
    return Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM ${AppDatabase.tasksTable} WHERE is_synced = 0')) ??
        0;
  }

  // ───────────────────────── Sincronización ─────────────────────────────
  /// ACK: marca como sincronizado SOLO si el registro no cambió durante el
  /// envío (misma `updated_at`). Si el usuario lo editó mientras subía, queda
  /// pendiente y se enviará en el siguiente ciclo (no se pierde ninguna edición).
  Future<void> markSynced(String id, DateTime sentUpdatedAt) async {
    final db = await _appDb.database;
    await db.update(
      AppDatabase.tasksTable,
      {'is_synced': 1},
      where: 'id = ? AND updated_at = ?',
      whereArgs: [id, sentUpdatedAt.toUtc().toIso8601String()],
    );
    _changes.add(null);
  }

  /// MERGE atómico (transacción) de un registro remoto con LWW.
  Future<MergeAction> mergeRemote(Task remote) async {
    final db = await _appDb.database;
    final action = await db.transaction<MergeAction>((txn) async {
      final rows = await txn.query(AppDatabase.tasksTable,
          where: 'id = ?', whereArgs: [remote.id], limit: 1);
      final local = rows.isEmpty ? null : Task.fromMap(rows.first);
      final decision = MergeResolver.resolve(local: local, remote: remote);
      if (decision != MergeAction.keepLocal) {
        await txn.insert(
          AppDatabase.tasksTable,
          remote.copyWith(isSynced: true).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      return decision;
    });
    if (action != MergeAction.keepLocal) _changes.add(null);
    return action;
  }

  // ───────────────────────── Metadatos de sync ──────────────────────────
  Future<String?> _getMeta(String key) async {
    final db = await _appDb.database;
    final rows = await db.query(AppDatabase.metaTable,
        where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> _setMeta(String key, String value) async {
    final db = await _appDb.database;
    await db.insert(AppDatabase.metaTable, {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getCursor() => _getMeta(_kCursor);
  Future<void> setCursor(String cursor) => _setMeta(_kCursor, cursor);
  Future<String?> getOwner() => _getMeta(_kOwner);

  /// Asocia la base local a un UID. Si pertenecía a OTRA cuenta, se purga
  /// primero: jamás se mezclan datos de dos usuarios.
  Future<void> bindOwner(String uid) async {
    final current = await getOwner();
    if (current != null && current != uid) await purgeAll();
    await _setMeta(_kOwner, uid);
  }

  // ───────────────────────── Limpieza de sesión ─────────────────────────
  /// Purga TOTAL: registros, cursor y dueño. VACUUM reescribe el archivo para
  /// no dejar páginas con datos borrados.
  Future<void> purgeAll() async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      await txn.delete(AppDatabase.tasksTable);
      await txn.delete(AppDatabase.metaTable);
    });
    await db.execute('VACUUM');
    _changes.add(null);
  }
}
