import 'data/local/app_database.dart';
import 'data/local/task_local_data_source.dart';
import 'data/remote/task_remote_data_source.dart';
import 'repositories/task_repository.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/secure_token_storage.dart';
import 'sync/sync_service.dart';

/// Contenedor de dependencias (inyección manual, sin paquetes extra).
/// Lo usan la UI (isolate principal) y Workmanager (isolate de fondo).
class AppDependencies {
  AppDependencies._({
    required this.tokens,
    required this.local,
    required this.remote,
    required this.connectivity,
    required this.auth,
    required this.sync,
    required this.repository,
  });

  factory AppDependencies.create() {
    final tokens = SecureTokenStorage();
    final local = TaskLocalDataSource(AppDatabase.instance);
    final remote = RemoteTaskDataSource();
    final connectivity = ConnectivityService();
    final auth = AuthService(tokens: tokens, local: local);
    final sync = SyncService(
        local: local, remote: remote, auth: auth, connectivity: connectivity);
    final repository =
        TaskRepository(local: local, sync: sync, connectivity: connectivity);
    return AppDependencies._(
      tokens: tokens,
      local: local,
      remote: remote,
      connectivity: connectivity,
      auth: auth,
      sync: sync,
      repository: repository,
    );
  }

  final SecureTokenStorage tokens;
  final TaskLocalDataSource local;
  final RemoteTaskDataSource remote;
  final ConnectivityService connectivity;
  final AuthService auth;
  final SyncService sync;
  final TaskRepository repository;
}
