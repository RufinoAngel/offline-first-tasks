import '../models/task.dart';

enum MergeAction {
  /// No existe localmente: se inserta lo remoto.
  insertRemote,

  /// Lo remoto es más reciente: sobrescribe lo local (LWW).
  applyRemote,

  /// Lo local es igual o más reciente (o no hay nada que hacer): se conserva.
  keepLocal,
}

/// Resolución de colisiones Last-Write-Wins (LWW).
///
/// Función PURA (sin I/O) para poder probarla con tests unitarios.
///
/// Regla: gana el registro con `updated_at` MÁS RECIENTE. En empate se
/// conserva el local (es determinista y evita ciclos de reescritura).
///
/// Limitación conocida de LWW: depende de relojes de dispositivos. Ver
/// docs/DOCUMENTACION_TECNICA.md §6 para cuándo usar versionado incremental.
class MergeResolver {
  static MergeAction resolve({required Task? local, required Task remote}) {
    if (local == null) {
      // Tombstone remoto de algo que nunca tuvimos: nada que insertar.
      return remote.isDeleted ? MergeAction.keepLocal : MergeAction.insertRemote;
    }
    if (remote.updatedAt.isAfter(local.updatedAt)) {
      return MergeAction.applyRemote;
    }
    return MergeAction.keepLocal;
  }
}
