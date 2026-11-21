# Guía breve para la lista de cotejo (Hacer · Saber · Ser)

## HACER — evidencia práctica
| Criterio | Dónde demostrarlo |
|---|---|
| CRUD con la nube | Crear/editar/eliminar en la app y ver los documentos en Firestore (`users/{uid}/tasks`). |
| Caché SQLite | Tabla `tasks` visible (🗄 o Database Inspector); la app funciona sin red. |
| Sync bidireccional | Push (Escenario 3 pasos 1-3) y Pull + merge LWW (pasos 5-6). |
| Red y segundo plano | Barra de estado reactiva; Workmanager con la app cerrada. |
| Pruebas obligatorias | `PLAN_DE_PRUEBAS.md` con las capturas de los 3 escenarios. |

## SABER — documentación técnica
Entrega `docs/DOCUMENTACION_TECNICA.md` y señala: **modelo de datos** (§3), **cifrado** (§7: Keystore/Keychain,
cifrado en reposo), **reglas del backend** (`firestore.rules`), ciclo Push/ACK/Pull/Merge (§5), idempotencia y
cuándo usar versionado en lugar de LWW (§6). Prepárate para explicar: ¿por qué `is_synced` se confirma solo si
`updated_at` no cambió?, ¿por qué el cursor usa hora del servidor?, ¿qué pasa si dos dispositivos editan a la vez?

## SER — buenas prácticas
**Commits continuos en Git** (pequeños, un cambio lógico por commit, mensajes en imperativo):
```
chore: crea proyecto Flutter y agrega dependencias
feat(db): agrega esquema SQLite con campos de sincronización
feat(model): agrega entidad Task con serialización local y remota
feat(local): implementa saveLocal con is_synced=0 y streams reactivos
feat(ui): lista reactiva con indicador de pendiente/sincronizado
feat(net): escucha onConnectivityChanged y barra de estado
feat(sync): implementa push, ack y pull incremental
feat(sync): resuelve conflictos con LWW y pruebas unitarias
feat(bg): programa Workmanager con NetworkType.connected
feat(security): guarda tokens con flutter_secure_storage
feat(auth): purga SQLite y tokens al cerrar sesión
docs: agrega documentación técnica, plan de pruebas y reglas
```
Haz commit al terminar cada punto (no un único commit final) y sube a GitHub con `git push`.

**Protección de datos:** `.gitignore` excluye `google-services.json` y llaves; no se registran tokens ni contenido
de usuarios en logs; tokens cifrados; reglas por UID; purga al cerrar sesión; aviso antes de descartar pendientes.
