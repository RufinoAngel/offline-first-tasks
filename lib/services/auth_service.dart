import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/local/task_local_data_source.dart';
import 'background_scheduler.dart';
import 'secure_token_storage.dart';

/// Identidad + ciclo de vida de la sesión local.
class AuthService {
  AuthService({
    required SecureTokenStorage tokens,
    required TaskLocalDataSource local,
    FirebaseAuth? auth,
  })  : _tokens = tokens,
        _local = local,
        _auth = auth ?? FirebaseAuth.instance;

  final SecureTokenStorage _tokens;
  final TaskLocalDataSource _local;
  final FirebaseAuth _auth;
  Future<void>? _binding;

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    await ensureSession();
  }

  Future<void> register(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    await ensureSession();
  }

  /// Idempotente. Garantiza que, para el usuario autenticado:
  ///  1) la BD local pertenece a SU uid (si era de otra cuenta, se purga);
  ///  2) uid + token están guardados en almacenamiento seguro.
  Future<void> ensureSession() {
    final user = _auth.currentUser;
    if (user == null) return Future.value();
    return _binding ??= _bind(user).whenComplete(() => _binding = null);
  }

  Future<void> _bind(User user) async {
    await _local.bindOwner(user.uid);
    String? token;
    try {
      token = await user.getIdToken();
    } catch (e) {
      // Sin red y token vencido: se conserva el último guardado.
      debugPrint('getIdToken sin red: ${e.runtimeType}');
    }
    await _tokens.saveSession(uid: user.uid, idToken: token);
  }

  /// Refresca el token (solo con red) y lo vuelve a cifrar en disco.
  Future<void> refreshStoredToken() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final token = await user.getIdToken();
    await _tokens.saveSession(uid: user.uid, idToken: token);
  }

  /// UID "validado": el de Firebase Auth DEBE coincidir con el guardado en
  /// almacenamiento seguro. Si no hay sesión coherente => null y NO se sincroniza.
  Future<String?> validatedUid() async {
    final user = _auth.currentUser;
    final stored = await _tokens.readUid();
    if (user == null || stored == null || user.uid != stored) return null;
    return user.uid;
  }

  /// Cierre de sesión seguro:
  ///  1) cancela tareas en segundo plano,
  ///  2) borra tokens del almacenamiento seguro,
  ///  3) PURGA SQLite (datos del usuario fuera del dispositivo),
  ///  4) cierra la sesión en Firebase.
  Future<void> signOut() async {
    await BackgroundScheduler.cancelAll();
    await _tokens.clear();
    await _local.purgeAll();
    await _auth.signOut();
  }
}
