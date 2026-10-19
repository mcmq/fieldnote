import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';

/// Local-first access to inspections. Every write also queues an outbox
/// entry in the same transaction (see docs/sync.md).
class InspectionRepository extends ChangeNotifier {
  InspectionRepository(this._db);

  final Database _db;

  static const maxAutoAttempts = 5;

  Future<List<Inspection>> list() async {
    final rows = await _db.query(
      'inspections',
      where: 'deleted = 0',
      orderBy: 'updated_at DESC',
    );
    return [for (final r in rows) await _hydrate(r)];
  }

  Future<Inspection?> get(String id) async {
    final rows = await _db.query(
      'inspections',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : _hydrate(rows.first);
  }

  Future<void> save(Inspection i) async {
    i.updatedAt = DateTime.now();
    i.syncState = SyncState.pending;
    await _db.transaction((txn) async {
      await txn.insert(
        'inspections',
        _toRow(i),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'checklist_items',
        where: 'inspection_id = ?',
        whereArgs: [i.id],
      );
      for (var n = 0; n < i.checklist.length; n++) {
        final c = i.checklist[n];
        await txn.insert('checklist_items', {
          'id': c.id,
          'inspection_id': i.id,
          'label': c.label,
          'result': c.result.name,
          'note': c.note,
          'position': n,
        });
      }
      await txn.delete('photos', where: 'inspection_id = ?', whereArgs: [i.id]);
      for (final p in i.photos) {
        await txn.insert('photos', {
          'id': p.id,
          'inspection_id': i.id,
          'local_path': p.localPath,
          'remote_url': p.remoteUrl,
          'uploaded': p.uploaded ? 1 : 0,
        });
      }
      await _enqueue(txn, i.id, 'upsert');
    });
    notifyListeners();
  }

  /// Soft delete so the deletion can sync.
  Future<void> delete(String id) async {
    await _db.transaction((txn) async {
      await txn.update(
        'inspections',
        {
          'deleted': 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          'sync_state': SyncState.pending.name,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _enqueue(txn, id, 'delete');
    });
    notifyListeners();
  }

  Future<void> _enqueue(DatabaseExecutor txn, String id, String op) async {
    await txn.delete('outbox', where: 'inspection_id = ?', whereArgs: [id]);
    await txn.insert('outbox', {
      'inspection_id': id,
      'op': op,
      'attempts': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ---- sync support -------------------------------------------------------

  Future<List<OutboxEntry>> outbox() async {
    final rows = await _db.query('outbox', orderBy: 'seq');
    return [
      for (final r in rows)
        OutboxEntry(
          seq: r['seq'] as int,
          inspectionId: r['inspection_id'] as String,
          op: r['op'] as String,
          attempts: r['attempts'] as int,
          lastError: r['last_error'] as String?,
        ),
    ];
  }

  Future<void> markPhotoUploaded(String photoId, String url) async {
    await _db.update(
      'photos',
      {'remote_url': url, 'uploaded': 1},
      where: 'id = ?',
      whereArgs: [photoId],
    );
  }

  /// Completes an outbox entry. The record only becomes `synced` if nothing
  /// newer was queued for it while the upload was running.
  Future<void> completeEntry(OutboxEntry e) async {
    await _db.transaction((txn) async {
      await txn.delete('outbox', where: 'seq = ?', whereArgs: [e.seq]);
      final newer = await txn.query(
        'outbox',
        where: 'inspection_id = ?',
        whereArgs: [e.inspectionId],
        limit: 1,
      );
      if (newer.isEmpty) {
        await txn.update(
          'inspections',
          {'sync_state': SyncState.synced.name},
          where: 'id = ?',
          whereArgs: [e.inspectionId],
        );
      }
    });
    notifyListeners();
  }

  Future<void> failEntry(OutboxEntry e, Object error) async {
    await _db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE outbox SET attempts = attempts + 1, last_error = ? WHERE seq = ?',
        [error.toString(), e.seq],
      );
      await txn.update(
        'inspections',
        {'sync_state': SyncState.failed.name},
        where: 'id = ?',
        whereArgs: [e.inspectionId],
      );
    });
    notifyListeners();
  }

  /// Gives failed entries a fresh set of automatic attempts.
  Future<void> resetFailed() async {
    await _db.update(
      'outbox',
      {'attempts': 0},
      where: 'attempts >= ?',
      whereArgs: [maxAutoAttempts],
    );
    notifyListeners();
  }

  // ---- mapping ------------------------------------------------------------

  Future<Inspection> _hydrate(Map<String, Object?> r) async {
    final id = r['id'] as String;
    final items = await _db.query(
      'checklist_items',
      where: 'inspection_id = ?',
      whereArgs: [id],
      orderBy: 'position',
    );
    final photos = await _db.query(
      'photos',
      where: 'inspection_id = ?',
      whereArgs: [id],
    );
    DateTime? ms(Object? v) =>
        v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);
    return Inspection(
      id: id,
      title: r['title'] as String,
      siteName: r['site_name'] as String,
      category: enumByName(
        InspectionCategory.values,
        r['category'] as String?,
        InspectionCategory.building,
      ),
      overallStatus: enumByName(
        OverallStatus.values,
        r['overall_status'] as String?,
        OverallStatus.pass,
      ),
      notes: (r['notes'] as String?) ?? '',
      latitude: r['latitude'] as double?,
      longitude: r['longitude'] as double?,
      accuracyMeters: r['accuracy_m'] as double?,
      capturedAt: ms(r['captured_at']),
      createdAt: ms(r['created_at'])!,
      updatedAt: ms(r['updated_at'])!,
      deleted: (r['deleted'] as int) == 1,
      syncState: enumByName(
        SyncState.values,
        r['sync_state'] as String?,
        SyncState.pending,
      ),
      checklist: [
        for (final c in items)
          ChecklistItem(
            id: c['id'] as String,
            label: c['label'] as String,
            result: enumByName(
              CheckResult.values,
              c['result'] as String?,
              CheckResult.na,
            ),
            note: (c['note'] as String?) ?? '',
          ),
      ],
      photos: [
        for (final p in photos)
          Photo(
            id: p['id'] as String,
            localPath: p['local_path'] as String,
            remoteUrl: p['remote_url'] as String?,
            uploaded: (p['uploaded'] as int) == 1,
          ),
      ],
    );
  }

  Map<String, Object?> _toRow(Inspection i) => {
    'id': i.id,
    'title': i.title,
    'site_name': i.siteName,
    'category': i.category.name,
    'overall_status': i.overallStatus.name,
    'notes': i.notes,
    'latitude': i.latitude,
    'longitude': i.longitude,
    'accuracy_m': i.accuracyMeters,
    'captured_at': i.capturedAt?.millisecondsSinceEpoch,
    'created_at': i.createdAt.millisecondsSinceEpoch,
    'updated_at': i.updatedAt.millisecondsSinceEpoch,
    'deleted': i.deleted ? 1 : 0,
    'sync_state': i.syncState.name,
  };
}
