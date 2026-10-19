import 'package:field_note/core/db/app_database.dart';
import 'package:field_note/core/remote/remote_gateway.dart';
import 'package:field_note/core/sync/sync_engine.dart';
import 'package:field_note/features/inspections/data/inspection_repository.dart';
import 'package:field_note/features/inspections/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeRemote implements RemoteGateway {
  bool offline = false;
  final upserts = <String>[];
  final deletes = <String>[];

  @override
  Future<String> uploadPhoto(String inspectionId, Photo photo) async {
    if (offline) throw NetworkUnavailable('offline');
    return 'https://example.com/${photo.id}.jpg';
  }

  @override
  Future<void> upsertInspection(Inspection i) async {
    if (offline) throw NetworkUnavailable('offline');
    upserts.add(i.id);
  }

  @override
  Future<void> markDeleted(String id) async {
    if (offline) throw NetworkUnavailable('offline');
    deletes.add(id);
  }
}

void main() {
  sqfliteFfiInit();
  late InspectionRepository repo;
  late FakeRemote remote;
  late SyncEngine engine;

  Inspection sample() => Inspection(
    id: 'a' * 36,
    title: 'Boiler',
    siteName: 'Plant 2',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    photos: [Photo(id: 'p1', localPath: '/tmp/p1.jpg')],
    checklist: [
      ChecklistItem(id: 'c1', label: 'Gauge', result: CheckResult.pass),
    ],
  );

  setUp(() async {
    final db = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    repo = InspectionRepository(db);
    remote = FakeRemote();
    engine = SyncEngine(repo, remote, isOnline: () async => true);
  });

  test('save stores locally as pending and queues an outbox entry', () async {
    await repo.save(sample());
    final list = await repo.list();
    expect(list.single.syncState, SyncState.pending);
    expect(list.single.checklist.single.label, 'Gauge');
    expect((await repo.outbox()).length, 1);
  });

  test('offline sync keeps data queued, online sync marks it synced', () async {
    await repo.save(sample());
    remote.offline = true;
    await engine.syncNow();
    expect((await repo.outbox()).length, 1);
    expect(engine.online, isFalse);

    remote.offline = false;
    await engine.syncNow();
    expect(await repo.outbox(), isEmpty);
    expect((await repo.list()).single.syncState, SyncState.synced);
    expect((await repo.list()).single.photos.single.uploaded, isTrue);
    expect(remote.upserts, ['a' * 36]);
  });

  test('delete is soft and syncs as a delete', () async {
    await repo.save(sample());
    await engine.syncNow();
    await repo.delete('a' * 36);
    expect(await repo.list(), isEmpty);
    await engine.syncNow();
    expect(remote.deletes, ['a' * 36]);
  });
}
