class AppConstants {
  static const dbName = 'offline_first.db';
  static const dbVersion = 1;

  /// Nombre único de la tarea en WorkManager (evita duplicados en cola).
  static const syncUniqueName = 'offline_first_sync_unique';

  /// Identificador lógico recibido en executeTask().
  static const syncTaskName = 'sync_tasks_task';

  /// Tiempo máximo por operación de red: evita bloqueos con redes "falsas".
  static const networkTimeout = Duration(seconds: 15);
}
