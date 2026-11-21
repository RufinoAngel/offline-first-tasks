import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';
import '../sync/sync_service.dart';

/// Refleja en la UI: conectividad, estado del sync y registros pendientes.
class SyncStatusBar extends StatelessWidget {
  const SyncStatusBar({
    super.key,
    required this.connectivity,
    required this.sync,
    required this.pending,
  });

  final ConnectivityService connectivity;
  final SyncService sync;
  final Stream<int> pending;

  static String _hhmm(DateTime d) {
    final l = d.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: connectivity.onlineStream,
      initialData: connectivity.isOnline,
      builder: (context, connSnap) {
        final online = connSnap.data ?? true;
        return ValueListenableBuilder<SyncStatus>(
          valueListenable: sync.status,
          builder: (context, st, _) {
            return StreamBuilder<int>(
              stream: pending,
              initialData: 0,
              builder: (context, pSnap) {
                final n = pSnap.data ?? 0;
                final pendingTxt =
                    n == 0 ? 'todo sincronizado' : '$n pendiente(s)';

                late final Color color;
                late final IconData icon;
                late final String text;
                if (!online) {
                  color = const Color(0xFF9A6927);
                  icon = Icons.cloud_off;
                  text = 'Sin conexión · trabajando en local · $pendingTxt';
                } else if (st.phase == SyncPhase.offline) {
                  color = const Color(0xFF9A6927);
                  icon = Icons.cloud_off;
                  text =
                      '${st.message ?? 'Servidor sin conexión'} · trabajando en local · $pendingTxt';
                } else if (st.phase == SyncPhase.syncing) {
                  color = const Color(0xFF397354);
                  icon = Icons.sync;
                  text = 'Sincronizando… · $pendingTxt';
                } else if (st.phase == SyncPhase.error) {
                  color = const Color(0xFFAC4945);
                  icon = Icons.error_outline;
                  text =
                      '${st.message ?? 'Error de sincronización'} · $pendingTxt';
                } else {
                  color = const Color(0xFF397354);
                  icon = Icons.cloud_done;
                  final last = st.lastSyncAt == null
                      ? 'sin sincronizar aún'
                      : 'última sync ${_hhmm(st.lastSyncAt!)}';
                  text = 'En línea · $last · $pendingTxt';
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      color: color.withValues(alpha: 0.09),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      child: Row(
                        children: [
                          Icon(icon, color: color, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(text,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                )),
                          ),
                        ],
                      ),
                    ),
                    if (online && st.phase == SyncPhase.syncing)
                      const LinearProgressIndicator(minHeight: 2),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
