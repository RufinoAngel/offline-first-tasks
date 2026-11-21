import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Escucha reactiva de conectividad.
///
/// OJO: connectivity_plus informa si hay una INTERFAZ de red (Wi-Fi, datos),
/// no si hay Internet real. Por eso SyncService usa timeouts y reintentos.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _online = true;

  bool get isOnline => _online;

  /// Emite solo cuando CAMBIA el estado (offline→online / online→offline).
  Stream<bool> get onlineStream => _controller.stream;

  Future<void> start() async {
    _online = _hasNetwork(await _connectivity.checkConnectivity());
    _sub ??= _connectivity.onConnectivityChanged.listen((results) {
      final now = _hasNetwork(results);
      if (now != _online) {
        _online = now;
        _controller.add(now);
      }
    });
  }

  /// Consulta puntual (la usa el isolate de Workmanager).
  Future<bool> checkNow() async {
    _online = _hasNetwork(await _connectivity.checkConnectivity());
    return _online;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }

  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
