# Plan de pruebas y evidencias — Unidad II

**Preparación:** build debug en un dispositivo/emulador Android, sesión iniciada **con Internet** (primer login requiere red),
consola de Firebase abierta en `users/{uid}/tasks`. En debug, el icono 🗄 de la barra muestra la tabla SQLite
(`sync=0/1`, `del=0/1`); alternativa: Android Studio → App Inspection → Database Inspector → `offline_first.db`.

## Escenario 1 — Modo avión: crear y editar ≥ 3 registros offline
| # | Paso | Resultado esperado |
|---|---|---|
| 1 | Activa **modo avión**. | Barra naranja "Sin conexión · trabajando en local". |
| 2 | Crea "Offline 1", "Offline 2", "Offline 3". | Aparecen al instante; icono ☁↑ (pendiente); contador "3 pendiente(s)". |
| 3 | Edita "Offline 2" → "Offline 2 (editada)". Elimina "Offline 3" deslizando. | Cambios inmediatos; "Offline 3" desaparece de la lista. |
| 4 | Revisa SQLite (🗄). | 3 filas con `sync=0`; "Offline 3" con `del=1` (tombstone); `updated_at` distinto por fila. |
| 5 | Revisa Firestore. | **Sin documentos nuevos.** |

**Evidencias:** captura de la lista + barra naranja, captura de la tabla SQLite, captura de Firestore sin datos.

## Escenario 2 — Cierre forzado y reinicio: persistencia
| # | Paso | Resultado esperado |
|---|---|---|
| 1 | Con el modo avión aún activo, cierra la app desde recientes (o `adb shell am force-stop <paquete>`). | — |
| 2 | Vuelve a abrir la app (sigue sin red). | Sesión conservada; las tareas siguen ahí, aún ☁↑ y "N pendiente(s)". |
| 3 | Revisa SQLite. | Mismas filas, `is_synced = 0`: nada se perdió. |

**Evidencias:** captura antes/después del cierre y de la tabla SQLite.

## Escenario 3 — Reconexión: subida automática y conciliación
| # | Paso | Resultado esperado |
|---|---|---|
| 1 | Desactiva el modo avión (app abierta). | Barra: "Sincronizando…" → verde "En línea · última sync HH:mm · todo sincronizado". |
| 2 | Observa la lista. | Iconos pasan a ☁✓; contador en 0 (sin pulsar nada). |
| 3 | Revisa Firestore. | Documentos `users/{uid}/tasks/{uuid}`: los UUID coinciden con SQLite; "Offline 3" con `is_deleted: true`; campo `server_updated_at`. |
| 4 | Pulsa "Sincronizar ahora" 2–3 veces. | **Sin duplicados** (idempotencia por UUID). |
| 5 | Conciliación (LWW): edita desde la consola de Firebase el título de un doc con `updated_at` **posterior** (ISO UTC, p. ej. mañana) y `server_updated_at` actualizado, y pulsa sincronizar. | La app muestra el título de la nube (gana el más reciente). |
| 6 | Repite con `updated_at` **anterior** al local. | Se conserva el valor local y se vuelve a subir si estaba pendiente. |

**Evidencias:** capturas de la barra en cada fase, de Firestore y del log `[sync]` (`flutter run`).

## Pruebas complementarias
- **Workmanager (app cerrada):** modo avión → crea 1 registro → cierra la app → desactiva modo avión → espera 1–2 min →
  verifica en Firestore (sin abrir la app). Reintento: `adb shell dumpsys jobscheduler | grep <paquete>`.
- **Cierre de sesión:** con pendientes y sin red → aparece el aviso de descarte. Tras cerrar sesión, 🗄/Database Inspector
  muestran `tasks` y `sync_meta` vacías; iniciar sesión con otra cuenta no muestra datos de la anterior.
- **Reglas:** en el simulador de reglas, un `uid` distinto debe obtener *permission-denied*; `delete` también.
- **Unitarias:** `flutter test` (LWW: inserta, gana remoto, gana local, empate, tombstone).

## Registro de resultados
| Escenario | Fecha | Resultado (✔/✘) | Evidencia (archivo) | Observaciones |
|---|---|---|---|---|
| 1 Modo avión | | | | |
| 2 Cierre forzado | | | | |
| 3 Reconexión | | | | |
