import 'package:flutter_test/flutter_test.dart';
import 'package:offline_first_tasks/models/task.dart';
import 'package:offline_first_tasks/sync/merge_resolver.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 19, 10, 0, 0);

  Task task({required DateTime at, bool synced = false, bool deleted = false}) =>
      Task(
          id: 'id-1',
          title: 't',
          updatedAt: at,
          isSynced: synced,
          isDeleted: deleted);

  group('MergeResolver (LWW)', () {
    test('inserta lo remoto si no existe localmente', () {
      expect(MergeResolver.resolve(local: null, remote: task(at: t0)),
          MergeAction.insertRemote);
    });

    test('ignora un tombstone remoto de algo que nunca tuvimos', () {
      expect(
          MergeResolver.resolve(local: null, remote: task(at: t0, deleted: true)),
          MergeAction.keepLocal);
    });

    test('gana lo remoto si es más reciente (aunque el local esté pendiente)', () {
      final local = task(at: t0);
      final remote = task(at: t0.add(const Duration(seconds: 1)), synced: true);
      expect(MergeResolver.resolve(local: local, remote: remote),
          MergeAction.applyRemote);
    });

    test('gana lo local si es más reciente', () {
      final local = task(at: t0.add(const Duration(seconds: 5)));
      final remote = task(at: t0, synced: true);
      expect(MergeResolver.resolve(local: local, remote: remote),
          MergeAction.keepLocal);
    });

    test('empate: se conserva lo local (determinista)', () {
      expect(
          MergeResolver.resolve(
              local: task(at: t0), remote: task(at: t0, synced: true)),
          MergeAction.keepLocal);
    });

    test('un borrado remoto más reciente se aplica (soft delete)', () {
      final remote = task(at: t0.add(const Duration(seconds: 2)), deleted: true);
      expect(MergeResolver.resolve(local: task(at: t0, synced: true), remote: remote),
          MergeAction.applyRemote);
    });
  });

  group('Task', () {
    test('toMap/fromMap conserva todos los campos', () {
      final original = task(at: t0, synced: true, deleted: true);
      final copy = Task.fromMap(original.toMap());
      expect(copy.id, original.id);
      expect(copy.updatedAt, original.updatedAt);
      expect(copy.isSynced, isTrue);
      expect(copy.isDeleted, isTrue);
    });

    test('toRemoteMap no expone is_synced', () {
      expect(task(at: t0).toRemoteMap().containsKey('is_synced'), isFalse);
    });
  });
}
