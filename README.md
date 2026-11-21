# Offline-First Tasks — Práctica Guiada (Cierre Unidad II)

App Flutter con arquitectura **Offline-First**: SQLite es la única fuente de verdad, la UI nunca espera a la red
y la sincronización con Firestore es bidireccional (Push → ACK → Pull → Merge LWW).

## 1. Puesta en marcha

```bash
# 1) Generar las carpetas de plataforma (android/ios) dentro de esta carpeta
flutter create --org mx.edu.utxj --project-name offline_first_tasks .
rm -f test/widget_test.dart          # el generado por defecto no aplica a este proyecto

# 2) Dependencias
flutter pub get                      # si hay conflicto de versiones: flutter pub upgrade

# 3) Firebase (Authentication correo/contraseña + Cloud Firestore)
#    - Crea el proyecto en la consola de Firebase y registra la app Android.
#    - Descarga google-services.json  ->  android/app/google-services.json
#    - Publica firestore.rules (Consola > Firestore > Reglas).

# 4) Ejecutar
flutter run
flutter test                         # pruebas unitarias de la resolución LWW
```

### Ajustes de Android (después de `flutter create`)
- `android/app/build.gradle(.kts)`: `minSdk = 23` (requerido por `flutter_secure_storage`) y aplicar el plugin
  `com.google.gms.google-services` (según la guía de FlutterFire de tu versión de Flutter).
- `AndroidManifest.xml`: permiso `INTERNET` (en release) — `ACCESS_NETWORK_STATE` lo añade `connectivity_plus`.
- Workmanager no necesita permisos extra en Android.

### iOS (opcional; ejecución en segundo plano "best effort")
En `Info.plist`: `UIBackgroundModes` → `fetch`, `processing` y `BGTaskSchedulerPermittedIdentifiers` con el
identificador de la tarea. iOS decide cuándo ejecutarla; las restricciones de `Constraints` se ignoran allí.

> Nota: las versiones de `pubspec.yaml` y la API de `workmanager` 0.9.x / `connectivity_plus` 6.x (que emite
> `List<ConnectivityResult>`) están escritas para esas versiones. El código no se compiló en el entorno donde fue
> generado; ejecuta `flutter analyze` y `flutter test` y corrige cualquier ajuste menor de versión.

## 2. Estructura

```
lib/
├─ main.dart                       Arranque: Firebase, Workmanager, conectividad
├─ app_dependencies.dart           Inyección manual (UI y Workmanager comparten la construcción)
├─ background_dispatcher.dart      callbackDispatcher() del isolate de Workmanager
├─ core/                           constantes, utilidades de tiempo UTC, bootstrap de Firebase
├─ models/task.dart                Entidad + metadatos de sync
├─ data/local/                     SQLite: app_database.dart + task_local_data_source.dart (saveLocal, streams)
├─ data/remote/                    Firestore: push idempotente + pull incremental
├─ sync/                           sync_service.dart (Push/ACK/Pull/Merge) y merge_resolver.dart (LWW puro)
├─ services/                       auth, secure storage, conectividad, programador de Workmanager
├─ repositories/task_repository.dart  Fachada para la UI (disco primero, red después)
└─ ui/                             login, lista reactiva, barra de estado de sync
docs/                              DOCUMENTACION_TECNICA.md · PLAN_DE_PRUEBAS.md · GUIA_LISTA_DE_COTEJO.md
firestore.rules                    Reglas de seguridad del backend
test/merge_resolver_test.dart      Pruebas unitarias de LWW y del modelo
```

## 3. Requisito → dónde está

| Requisito | Archivo |
|---|---|
| Dependencias explicadas | `pubspec.yaml` (comentarios) · `docs/DOCUMENTACION_TECNICA.md` §2 |
| Tabla con `id`, `title`, `is_synced`, `updated_at`, `is_deleted` | `data/local/app_database.dart` |
| `saveLocal` (escritura inmediata, `is_synced = 0`) | `data/local/task_local_data_source.dart` |
| UI reactiva sin esperar a la red | `watchVisible()` + `StreamBuilder` en `ui/tasks_page.dart` |
| `onConnectivityChanged` → sync automático | `services/connectivity_service.dart` + `TaskRepository.start()` |
| `registerOneOffTask` + `NetworkType.connected` | `services/background_scheduler.dart` |
| Push → ACK → Pull → Merge (LWW) | `sync/sync_service.dart` + `sync/merge_resolver.dart` |
| Idempotencia por UUID | `data/remote/task_remote_data_source.dart` (`doc(task.id).set`) |
| Tokens cifrados | `services/secure_token_storage.dart` |
| Validación de UID / reglas | `AuthService.validatedUid()` + `firestore.rules` |
| Purga de SQLite al cerrar sesión | `AuthService.signOut()` → `purgeAll()` |
