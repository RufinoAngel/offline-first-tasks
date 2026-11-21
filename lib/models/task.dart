import '../core/time_utils.dart';

/// Entidad principal. Incluye los metadatos de sincronización.
class Task {
  const Task({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
  });

  /// UUID v4 generado en el cliente (clave de idempotencia).
  final String id;
  final String title;

  /// Última modificación (UTC). Base de la resolución LWW.
  final DateTime updatedAt;

  /// false = pendiente de enviar a la nube.
  final bool isSynced;

  /// Borrado lógico (tombstone): el registro se oculta pero sigue existiendo
  /// hasta que la nube se entere del borrado.
  final bool isDeleted;

  Task copyWith({
    String? title,
    DateTime? updatedAt,
    bool? isSynced,
    bool? isDeleted,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        updatedAt: updatedAt ?? this.updatedAt,
        isSynced: isSynced ?? this.isSynced,
        isDeleted: isDeleted ?? this.isDeleted,
      );

  // ── SQLite ──────────────────────────────────────────────────────────────
  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'is_synced': isSynced ? 1 : 0,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory Task.fromMap(Map<String, Object?> m) => Task(
        id: m['id'] as String,
        title: m['title'] as String,
        isSynced: (m['is_synced'] as int) == 1,
        updatedAt: normalizeUtc(DateTime.parse(m['updated_at'] as String)),
        isDeleted: (m['is_deleted'] as int) == 1,
      );

  // ── Nube ────────────────────────────────────────────────────────────────
  /// `is_synced` no viaja: es un metadato puramente local.
  Map<String, Object?> toRemoteMap() => {
        'id': id,
        'title': title,
        'is_deleted': isDeleted,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory Task.fromRemoteMap(Map<String, dynamic> m) => Task(
        id: m['id'] as String,
        title: (m['title'] as String?) ?? '',
        isDeleted: (m['is_deleted'] as bool?) ?? false,
        updatedAt: normalizeUtc(DateTime.parse(m['updated_at'] as String)),
        isSynced: true, // lo que viene de la nube ya está sincronizado
      );

  @override
  String toString() =>
      'Task($id, "$title", synced=$isSynced, del=$isDeleted, $updatedAt)';
}
