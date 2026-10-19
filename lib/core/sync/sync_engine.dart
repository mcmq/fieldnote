import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../../features/inspections/data/inspection_repository.dart';
import '../../features/inspections/domain/models.dart';
import '../remote/remote_gateway.dart';

/// Drains the outbox to Firebase. Safe to call from any trigger; overlapping
/// runs are ignored (see docs/sync.md).
class SyncEngine extends ChangeNotifier {
  SyncEngine(this._repo, this._remote, {Future<bool> Function()? isOnline})
    : _isOnline = isOnline ?? _defaultIsOnline;

  final InspectionRepository _repo;
  final RemoteGateway _remote;
  final Future<bool> Function() _isOnline;

  bool _running = false;
  bool get isSyncing => _running;

  DateTime? lastSyncAt;
  String? lastError;
  bool online = true;

  void setOnline(bool value) {
    online = value;
    notifyListeners();
  }

  static Future<bool> _defaultIsOnline() async {
    final r = await Connectivity().checkConnectivity();
    return !r.contains(ConnectivityResult.none);
  }

  Future<void> syncNow({bool retryFailed = false}) async {
    if (_running) return;
    _running = true;
    lastError = null;
    notifyListeners();
    try {
      online = await _isOnline();
      if (!online) return;
      if (retryFailed) await _repo.resetFailed();
      for (final entry in await _repo.outbox()) {
        if (entry.attempts >= InspectionRepository.maxAutoAttempts) continue;
        try {
          await _push(entry);
        } on NetworkUnavailable catch (e) {
          lastError = e.toString();
          online = false;
          break; // retry on the next trigger
        } catch (e) {
          lastError = e.toString();
          await _repo.failEntry(entry, e);
        }
      }
      if (lastError == null) lastSyncAt = DateTime.now();
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<void> _push(OutboxEntry entry) async {
    if (entry.op == 'delete') {
      await _remote.markDeleted(entry.inspectionId);
      return _repo.completeEntry(entry);
    }
    final inspection = await _repo.get(entry.inspectionId);
    if (inspection == null) return _repo.completeEntry(entry);
    for (final photo in inspection.photos.where((p) => !p.uploaded)) {
      final url = await _remote.uploadPhoto(inspection.id, photo);
      await _repo.markPhotoUploaded(photo.id, url);
      photo
        ..remoteUrl = url
        ..uploaded = true;
    }
    await _remote.upsertInspection(inspection);
    await _repo.completeEntry(entry);
  }
}
