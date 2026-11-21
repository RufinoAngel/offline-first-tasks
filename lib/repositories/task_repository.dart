import 'dart:async';

import '../data/local/task_local_data_source.dart';
import '../models/task.dart';
import '../services/background_scheduler.dart';
import '../services/connectivity_service.dart';
import '../sync/sync_service.dart';

/// Fachada que usa la UI. Regla de oro: toda escritura va PRIMERO a SQLite;
/// la red es un efecto secundario que nunca bloquea la interfaz.
class TaskRepository {
  TaskRepository({
    required TaskLocalDataSource local,
    required SyncService sync,
    required ConnectivityService connectivity,
  })  : _local = local,
        _sync = sync,
        _connectivity = connectivity;

  final TaskLocalDataSource _local;
  final SyncService _sync;
  final ConnectivityService _connectivity;
  StreamSubscription<bool>? _connSub;

  // ── Lectura reactiva (siempre desde SQLite) ───────────────────────────
  Stream<List<Task>> watchTasks() => _local.watchVisible();
  Stream<int> watchPendingCount() => _local.watchPendingCount();
  Future<int> pendingCount() => _local.pendingCount();
  Future<List<Task>> debugDump() => _local.dumpAll();

  // ── Escritura: disco primero, red después ─────────────────────────────
  Future<void> add(String title) async {
    await _local.create(title);
    _afterLocalWrite();
  }

  Future<void> rename(String id, String title) async {
    await _local.updateTitle(id, title);
    _afterLocalWrite();
  }

  Future<void> remove(String id) async {
    await _local.softDelete(id);
    _afterLocalWrite();
  }

  void _afterLocalWrite() {
    // 1) Resiliencia con la app cerrada: tarea diferida con red requerida.
    unawaited(BackgroundScheduler.scheduleSync());
    // 2) Si hay red ahora mismo, sincroniza de inmediato (sin bloquear la UI).
    if (_connectivity.isOnline) unawaited(_sync.sync(trigger: 'local-write'));
  }

  // ── Ciclo de vida ─────────────────────────────────────────────────────
  /// Escucha Connectivity().onConnectivityChanged y sincroniza al reconectar.
  void start() {
    _connSub ??= _connectivity.onlineStream.listen((online) {
      if (online) unawaited(_sync.sync(trigger: 'connectivity-restored'));
    });
    if (_connectivity.isOnline) unawaited(_sync.sync(trigger: 'start'));
  }

  void stop() {
    _connSub?.cancel();
    _connSub = null;
  }

  Future<void> syncNow() => _sync.sync(trigger: 'manual');

  /// Al volver a primer plano: Workmanager pudo haber escrito en el .db desde
  /// otro isolate, así que se refresca la UI y se intenta sincronizar.
  Future<void> onAppResumed() async {
    _local.notifyExternalChange();
    await _connectivity.checkNow();
    await _sync.sync(trigger: 'resume');
  }
}
