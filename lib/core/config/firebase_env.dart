import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads `.env` (bundled as an asset). Call once per isolate before
/// [firebaseOptions]; the background sync isolate must call it too.
Future<void> loadEnv() => dotenv.load();

String _get(String key) {
  final v = dotenv.maybeGet(key);
  if (v == null || v.isEmpty) {
    throw StateError('Missing $key in .env (see .env.example).');
  }
  return v;
}

/// Firebase options for the current platform, built from `.env`.
FirebaseOptions firebaseOptions() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return FirebaseOptions(
        apiKey: _get('FIREBASE_ANDROID_API_KEY'),
        appId: _get('FIREBASE_ANDROID_APP_ID'),
        messagingSenderId: _get('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _get('FIREBASE_PROJECT_ID'),
        storageBucket: _get('FIREBASE_STORAGE_BUCKET'),
      );
    case TargetPlatform.iOS:
      return FirebaseOptions(
        apiKey: _get('FIREBASE_IOS_API_KEY'),
        appId: _get('FIREBASE_IOS_APP_ID'),
        messagingSenderId: _get('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _get('FIREBASE_PROJECT_ID'),
        storageBucket: _get('FIREBASE_STORAGE_BUCKET'),
        iosBundleId: _get('FIREBASE_IOS_BUNDLE_ID'),
      );
    default:
      throw UnsupportedError(
        'Firebase is only configured for Android and iOS.',
      );
  }
}
