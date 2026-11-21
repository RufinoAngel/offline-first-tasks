import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants.dart';
import '../../models/task.dart';

class PullResult {
  const PullResult(this.tasks, this.cursor);
  final List<Task> tasks;

  /// Nuevo cursor ("segundos:nanosegundos" del último server_updated_at visto).
  final String? cursor;
}

/// Capa remota (Firestore). Ruta: users/{uid}/tasks/{taskId}
///
/// • El documento usa el UUID del cliente como ID  => PUSH IDEMPOTENTE:
///   reintentar el mismo envío sobrescribe el mismo documento, nunca duplica.
/// • El UID forma parte de la ruta y las reglas de seguridad exigen
///   request.auth.uid == uid (ver firestore.rules).
/// • El cursor del PULL usa `server_updated_at` (hora del SERVIDOR) y no el
///   `updated_at` del cliente: así un dispositivo con el reloj atrasado no
///   puede "esconder" cambios de los demás.
class RemoteTaskDataSource {
  RemoteTaskDataSource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('tasks');

  /// PUSH con LWW también en el servidor: si la nube ya tiene una versión más
  /// nueva, NO se sobrescribe (el ciclo PULL traerá la versión ganadora).
  Future<void> push(String uid, Task task) async {
    final ref = _col(uid).doc(task.id);
    await _db.runTransaction<void>(
      (tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) {
          final remoteUpdated = DateTime.tryParse(
              (snap.data()?['updated_at'] as String?) ?? '');
          if (remoteUpdated != null &&
              remoteUpdated.isAfter(task.updatedAt)) {
            return; // la nube gana; el ACK local es válido (se corrige en el PULL)
          }
        }
        tx.set(ref, {
          ...task.toRemoteMap(),
          'server_updated_at': FieldValue.serverTimestamp(),
        });
      },
      timeout: AppConstants.networkTimeout,
    ).timeout(AppConstants.networkTimeout);
  }

  /// PULL incremental: solo documentos modificados después del cursor.
  Future<PullResult> pullSince(String uid, String? cursor) async {
    Query<Map<String, dynamic>> query =
        _col(uid).orderBy('server_updated_at');
    if (cursor != null) {
      final parts = cursor.split(':');
      query = query.where(
        'server_updated_at',
        isGreaterThan: Timestamp(int.parse(parts[0]), int.parse(parts[1])),
      );
    }
    final snap = await query
        .get(const GetOptions(source: Source.server))
        .timeout(AppConstants.networkTimeout);

    Timestamp? maxTs;
    final tasks = <Task>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final ts = data['server_updated_at'];
      if (ts is Timestamp && (maxTs == null || ts.compareTo(maxTs) > 0)) {
        maxTs = ts;
      }
      if (data['updated_at'] is! String) continue; // documento malformado
      tasks.add(Task.fromRemoteMap({...data, 'id': doc.id}));
    }
    return PullResult(
      tasks,
      maxTs == null ? cursor : '${maxTs.seconds}:${maxTs.nanoseconds}',
    );
  }
}
