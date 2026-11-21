import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../data/local/task_local_data_source.dart';
import '../data/remote/task_remote_data_source.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import 'merge_resolver.dart';

enum SyncPhase { idle, syncing, offline, error }

class SyncStatus {
  const SyncStatus({
    this.phase = SyncPhase.idle,
    this.lastSyncAt,
    this.message,
    this.pushed = 0,
    this.pulled = 0,
  });

  final SyncPhase phase;
  final DateTime? lastSyncAt;
  final String? message;
  final int pushed;
  final int pulled;
}

/// Ciclo bidireccional:  PUSH → ACK → PULL → MERGE
class SyncService {
  SyncService({
    required TaskLocalDataSource local,
    required RemoteTaskDataSource remote,
    required AuthService auth,
    required ConnectivityService connectivity,
  })  : _local = local,
        _remote = remote,
        _auth = auth,
        _connectivity = connectivity;

  final TaskLocalDataSource _local;
  final RemoteTaskDataSource _remote;
  final AuthService _auth;
  final ConnectivityService _connectivity;

  final ValueNotifier<SyncStatus> status =
      ValueNotifier<SyncStatus>(const SyncStatus());

  bool _running = false; // exclusión mutua: un solo ciclo a la vez
  DateTime? _lastSyncAt;

  SyncStatus _set(SyncStatus s) {
    status.value = s;
    return s;
  }

  Future<SyncStatus> sync({String trigger = 'manual'}) async {
    if (_running) return status.value;
    _running = true;
    try {
      if (!await _connectivity.checkNow()) {
        return _set(SyncStatus(
            phase: SyncPhase.offline,
            lastSyncAt: _lastSyncAt,
            message: 'Sin conexión'));
      }

      // ── Identidad: UID de Firebase == UID en almacenamiento seguro ──────
      final uid = await _auth.validatedUid();
      if (uid == null) {
        debugPrint('[sync] sin sesión válida (uid null)');
        return _set(SyncStatus(
            lastSyncAt: _lastSyncAt, message: 'Sin sesión válida'));
      }
      // ── Aislamiento: la BD local debe pertenecer a este UID ─────────────
      if (await _local.getOwner() != uid) {
        debugPrint('[sync] la BD local pertenece a otra cuenta');
        return _set(SyncStatus(
            phase: SyncPhase.error,
            lastSyncAt: _lastSyncAt,
            message: 'La base local pertenece a otra cuenta'));
      }

      _set(SyncStatus(phase: SyncPhase.syncing, lastSyncAt: _lastSyncAt));
      debugPrint('[sync] inicio (trigger: $trigger, uid: $uid)');
      await _auth.refreshStoredToken();

      // ── 1) PUSH  +  2) ACK ──────────────────────────────────────────────
      var pushed = 0;
      var failed = 0;
      var transientPushFailure = false;
      String? firstError;
      for (final task in await _local.getPending()) {
        try {
          await _remote.push(uid, task); // idempotente por UUID
          await _local.markSynced(task.id, task.updatedAt); // ACK
          pushed++;
        } catch (e) {
          failed++;
          firstError ??= _describe(e);
          debugPrint('[sync] push falló (${task.id}): $e');
          if (_isTransient(e)) {
            transientPushFailure = true;
            break; // red caída: no insistir registro por registro
          }
        }
      }

      if (transientPushFailure) {
        return _set(SyncStatus(
          phase: SyncPhase.offline,
          lastSyncAt: _lastSyncAt,
          pushed: pushed,
          message: 'Servidor temporalmente no disponible',
        ));
      }

      // ── 3) PULL  +  4) MERGE (LWW) ─────────────────────────────────────
      var pulled = 0;
      final result = await _remote.pullSince(uid, await _local.getCursor());
      for (final remote in result.tasks) {
        final action = await _local.mergeRemote(remote);
        if (action != MergeAction.keepLocal) pulled++;
      }
      if (result.cursor != null) await _local.setCursor(result.cursor!);

      if (failed > 0) {
        return _set(SyncStatus(
            phase: SyncPhase.error,
            lastSyncAt: _lastSyncAt,
            pushed: pushed,
            pulled: pulled,
            message: '$failed sin enviar ($firstError)'));
      }
      _lastSyncAt = DateTime.now();
      debugPrint('[sync] ok: enviados=$pushed, recibidos=$pulled');
      return _set(SyncStatus(
          lastSyncAt: _lastSyncAt, pushed: pushed, pulled: pulled));
    } catch (e, st) {
      if (_isTransient(e)) {
        debugPrint('[sync] servidor temporalmente no disponible: ${_describe(e)}');
        return _set(SyncStatus(
          phase: SyncPhase.offline,
          lastSyncAt: _lastSyncAt,
          message: 'Servidor temporalmente no disponible',
        ));
      }
      debugPrint('[sync] error: $e\n$st');
      return _set(SyncStatus(
          phase: SyncPhase.error,
          lastSyncAt: _lastSyncAt,
          message: 'Error de sync (${_describe(e)})'));
    } finally {
      _running = false;
    }
  }

  /// Texto corto y útil para mostrar en la barra de estado.
  static String _describe(Object e) {
    if (e is FirebaseException) return e.code;
    if (e is TimeoutException) return 'timeout';
    return e.runtimeType.toString();
  }

  static bool _isTransient(Object e) =>
      e is TimeoutException ||
      (e is FirebaseException &&
          (e.code == 'unavailable' ||
              e.code == 'deadline-exceeded' ||
              e.code == 'network-request-failed'));
}