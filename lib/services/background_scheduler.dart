import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../core/constants.dart';

/// Programación de la sincronización diferida con Workmanager.
/// (Solo Android/iOS; en otras plataformas es un no-op.)
class BackgroundScheduler {
  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> initialize(Function callbackDispatcher) async {
    if (!_supported) return;
    await Workmanager().initialize(callbackDispatcher);
  }

  /// Encola UNA tarea única que el sistema ejecutará cuando haya red,
  /// aunque la app esté cerrada.
  ///
  /// • NetworkType.connected: no corre sin red (no gasta batería en vano).
  /// • requiresBatteryNotLow: respeta el ahorro de energía.
  /// • ExistingWorkPolicy.replace + initialDelay: varias escrituras seguidas
  ///   se agrupan en una sola ejecución (debounce).
  /// • Backoff exponencial: si falla (executeTask devuelve false) reintenta.
  static Future<void> scheduleSync() async {
    if (!_supported) return;
    try {
      await Workmanager().registerOneOffTask(
        AppConstants.syncUniqueName,
        AppConstants.syncTaskName,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        initialDelay: const Duration(seconds: 5),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 30),
      );
    } catch (e) {
      debugPrint('No se pudo programar Workmanager: $e');
    }
  }

  static Future<void> cancelAll() async {
    if (!_supported) return;
    try {
      await Workmanager().cancelAll();
    } catch (e) {
      debugPrint('No se pudo cancelar Workmanager: $e');
    }
  }
}
