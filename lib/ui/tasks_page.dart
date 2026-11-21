import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_dependencies.dart';
import '../models/task.dart';
import 'sync_status_bar.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key, required this.deps});
  final AppDependencies deps;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> with WidgetsBindingObserver {
  AppDependencies get _deps => widget.deps;

  // Los streams se crean UNA sola vez (no dentro de build()).
  late final Stream<List<Task>> _tasks = _deps.repository.watchTasks();
  late final Stream<int> _pending = _deps.repository.watchPendingCount();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  Future<void> _boot() async {
    await _deps.auth.ensureSession(); // liga BD↔UID y guarda token cifrado
    if (!mounted) return;
    _deps.repository.start(); // escucha conectividad + primer sync
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deps.repository.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _deps.repository.onAppResumed();
  }

  // ───────────────────────── Acciones ───────────────────────────────────
  Future<void> _add() async {
    final title = await showDialog<String>(
        context: context, builder: (_) => const _TitleDialog(title: 'Nueva tarea'));
    if (title != null && title.trim().isNotEmpty) {
      await _deps.repository.add(title);
    }
  }

  Future<void> _edit(Task task) async {
    final title = await showDialog<String>(
        context: context,
        builder: (_) =>
            _TitleDialog(title: 'Editar tarea', initial: task.title));
    if (title != null && title.trim().isNotEmpty && title.trim() != task.title) {
      await _deps.repository.rename(task.id, title);
    }
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      var left = await _deps.repository.pendingCount();
      if (left > 0 && _deps.connectivity.isOnline) {
        await _deps.repository.syncNow(); // último intento de subir pendientes
        left = await _deps.repository.pendingCount();
      }
      if (left > 0) {
        if (!mounted) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cambios sin sincronizar'),
            content: Text('Hay $left cambio(s) que aún no están en la nube. '
                'Si cierras sesión se ELIMINARÁN de este dispositivo.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Descartar y salir')),
            ],
          ),
        );
        if (discard != true) return;
      }
      await _deps.auth.signOut(); // cancela bg + borra tokens + purga SQLite
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showDebugDump() async {
    final all = await _deps.repository.debugDump();
    if (!mounted) return;
    final lines = all
        .map((t) =>
            '${t.id.substring(0, 8)} | ${t.title} | sync=${t.isSynced ? 1 : 0} '
            '| del=${t.isDeleted ? 1 : 0}\n   ${t.updatedAt.toIso8601String()}')
        .join('\n');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('SQLite · tabla tasks (${all.length})'),
        content: SingleChildScrollView(
          child: Text(lines.isEmpty ? '(vacía)' : lines,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))
        ],
      ),
    );
  }

  // ───────────────────────── UI ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis tareas',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (kDebugMode)
            IconButton(
                tooltip: 'Ver tabla SQLite (evidencia)',
                icon: const Icon(Icons.storage),
                onPressed: _showDebugDump),
          IconButton(
              tooltip: 'Sincronizar ahora',
              icon: const Icon(Icons.sync),
              onPressed: _busy ? null : _deps.repository.syncNow),
          IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: _busy ? null : _logout),
        ],
      ),
      floatingActionButton:
          FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: Column(
        children: [
          SyncStatusBar(
              connectivity: _deps.connectivity,
              sync: _deps.sync,
              pending: _pending),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: _tasks,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error local: ${snap.error}'));
                }
                final tasks = snap.data;
                if (tasks == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (tasks.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5EFE6),
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: const Icon(
                              Icons.checklist_rounded,
                              size: 38,
                              color: Color(0xFF1F5A45),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Un nuevo comienzo',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: const Color(0xFF183D31),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Todavía no tienes tareas.\nAgrega la primera y organiza tu día.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF718078),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (context, i) => _TaskTile(
                    task: tasks[i],
                    onTap: () => _edit(tasks[i]),
                    onDelete: () => _deps.repository.remove(tasks[i].id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile(
      {required this.task, required this.onTap, required this.onDelete});
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  static String _stamp(DateTime d) {
    final l = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)} ${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE8EDE7)),
        ),
        title: Text(task.title),
        subtitle: Text('Modificado ${_stamp(task.updatedAt)}'),
        onTap: onTap,
        trailing: Tooltip(
          message: task.isSynced ? 'Sincronizado' : 'Pendiente de enviar',
          child: Icon(
            task.isSynced ? Icons.cloud_done : Icons.cloud_upload_outlined,
            color: task.isSynced
                ? const Color(0xFF397354)
                : const Color(0xFFB77B32),
          ),
        ),
      ),
    );
  }
}

class _TitleDialog extends StatefulWidget {
  const _TitleDialog({required this.title, this.initial = ''});
  final String title;
  final String initial;

  @override
  State<_TitleDialog> createState() => _TitleDialogState();
}

class _TitleDialogState extends State<_TitleDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 200,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Título'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: const Text('Guardar')),
      ],
    );
  }
}
