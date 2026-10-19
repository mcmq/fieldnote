import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/inspections/domain/models.dart';
import '../platform/photo_store.dart';

/// Thrown when the failure is connectivity-related, so the engine should stop
/// and retry on the next trigger instead of burning attempts.
class NetworkUnavailable implements Exception {
  NetworkUnavailable(this.cause);
  final Object cause;
  @override
  String toString() => 'Network unavailable: $cause';
}

/// Max size of one encoded photo; keeps the Firestore doc under 1 MiB.
const maxPhotoBytes = 700 * 1024;

abstract class RemoteGateway {
  Future<String> uploadPhoto(String inspectionId, Photo photo);
  Future<void> upsertInspection(Inspection inspection);
  Future<void> markDeleted(String inspectionId);
}

class FirebaseRemoteGateway implements RemoteGateway {
  final _firestore = FirebaseFirestore.instance;

  /// Rules require an authenticated user; anonymous auth is enough here.
  Future<void> _ensureAuth() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      await _ensureAuth();
      return await body();
    } on SocketException catch (e) {
      throw NetworkUnavailable(e);
    } on FirebaseException catch (e) {
      const network = {
        'unavailable',
        'network-request-failed',
        'retry-limit-exceeded',
        'deadline-exceeded',
      };
      if (network.contains(e.code)) throw NetworkUnavailable(e);
      rethrow;
    }
  }

  /// Firebase Storage needs a paid plan, so photos are stored as small
  /// base64 JPEGs in a Firestore subcollection (1 MiB document limit).
  /// Returns the document path used as the photo's remote reference.
  @override
  Future<String> uploadPhoto(String inspectionId, Photo photo) =>
      _guard(() async {
        final bytes = await PhotoStore.resolve(photo.localPath).readAsBytes();
        if (bytes.length > maxPhotoBytes) {
          throw StateError('Photo too large (${bytes.length} bytes)');
        }
        final path = 'inspections/$inspectionId/photos/${photo.id}';
        await _firestore.doc(path).set({
          'data': base64Encode(bytes),
          'bytes': bytes.length,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
        return path;
      });

  @override
  Future<void> upsertInspection(Inspection i) => _guard(
    () => _firestore.collection('inspections').doc(i.id).set(i.toRemote()),
  );

  @override
  Future<void> markDeleted(String id) => _guard(
    () => _firestore.collection('inspections').doc(id).set({
      'deleted': true,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true)),
  );
}
