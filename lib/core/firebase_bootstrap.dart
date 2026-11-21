import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

Future<void> bootstrapFirebase() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  try {
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: false);
  } catch (e) {
    debugPrint('Firestore settings ya aplicados: $e');
  }
}