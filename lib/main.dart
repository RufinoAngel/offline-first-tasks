import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'background_dispatcher.dart';
import 'core/firebase_bootstrap.dart';
import 'services/background_scheduler.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await bootstrapFirebase();
    await BackgroundScheduler.initialize(callbackDispatcher);

    final deps = AppDependencies.create();
    await deps.connectivity.start();

    runApp(OfflineFirstApp(deps: deps));
  } catch (e, st) {
    debugPrint('Error de arranque: $e\n$st');
    runApp(MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Text('Error de arranque:\n\n$e\n\n$st'),
            ),
          ),
        ),
      ),
    ));
  }
}