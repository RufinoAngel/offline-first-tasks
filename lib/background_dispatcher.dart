import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'app_dependencies.dart';
import 'core/firebase_bootstrap.dart';
import 'sync/sync_service.dart';

/// Punto de entrada del isolate de Workmanager (app cerrada o en segundo plano).
/// Debe ser una función de nivel superior con @pragma('vm:entry-point').
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      DartPluginRegistrant.ensureInitialized();
      WidgetsFlutterBinding.ensureInitialized();
      await bootstrapFirebase();
      final deps = AppDependencies.create();
      final status = await deps.sync.sync(trigger: 'workmanager:$task');
      // true  => tarea completada (también si no hay sesión: nada que hacer).
      // false => Workmanager reintenta con backoff exponencial.
      return status.phase == SyncPhase.idle;
    } catch (e) {
      debugPrint('[workmanager] error: ${e.runtimeType}');
      return false;
    }
  });
}
