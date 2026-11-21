import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tokens y UID en almacenamiento CIFRADO EN REPOSO:
///  • Android: Android Keystore + EncryptedSharedPreferences.
///  • iOS: Keychain (accesible tras el primer desbloqueo, para que Workmanager
///    pueda leerlo con el teléfono bloqueado, y sin migrar a otros equipos).
/// Nunca se usa SharedPreferences ni SQLite para guardar tokens.
class SecureTokenStorage {
  SecureTokenStorage()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device),
        );

  final FlutterSecureStorage _storage;

  static const _kUid = 'session_uid';
  static const _kIdToken = 'session_id_token';

  Future<void> saveSession({required String uid, String? idToken}) async {
    await _storage.write(key: _kUid, value: uid);
    if (idToken != null && idToken.isNotEmpty) {
      await _storage.write(key: _kIdToken, value: idToken);
    }
  }

  Future<String?> readUid() => _storage.read(key: _kUid);
  Future<String?> readIdToken() => _storage.read(key: _kIdToken);

  /// Borra TODO el material de sesión (cierre de sesión).
  Future<void> clear() => _storage.deleteAll();
}
