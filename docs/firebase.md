# Firebase Setup

- Project ID: `fieldnote-5801c`
- Services used: **Cloud Firestore**, **Firebase Auth (anonymous)**. Firebase Storage is deliberately not used (paid plan); see docs/data-model.md for how photos are stored.
- Platforms configured: Android, iOS (options read from `.env` at runtime)

## Configuration (`.env`)
Firebase client config is **not committed**. It lives in a local `.env` (bundled as an asset and read with `flutter_dotenv` in `lib/core/config/firebase_env.dart`).

```bash
cp .env.example .env   # then fill in the values
```
Get the values from Firebase console -> Project settings -> Your apps (Android + iOS). Keys: `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_ANDROID_API_KEY`, `FIREBASE_ANDROID_APP_ID`, `FIREBASE_IOS_API_KEY`, `FIREBASE_IOS_APP_ID`, `FIREBASE_IOS_BUNDLE_ID`.

- `.env`, `google-services.json`, `GoogleService-Info.plist` and `firebase_options.dart` are gitignored. The build needs `.env` to exist (it is a pubspec asset).
- The background sync isolate calls `loadEnv()` too.
- Firebase API keys are identifiers, not secrets, and anything bundled in an app can be extracted. Real protection is the security rules above plus API key restrictions (Google Cloud console -> Credentials: restrict by Android package / iOS bundle ID).
- No FlutterFire CLI step or google-services Gradle plugin is used.

## Initialise in code
```dart
WidgetsFlutterBinding.ensureInitialized();
await loadEnv();
await Firebase.initializeApp(options: firebaseOptions());
FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
```

## Console steps still required
1. Enable **Firestore** (production mode).
2. Enable **Authentication → Anonymous** so rules can require `request.auth != null`.
3. Deploy rules below.

## Security rules
In `firestore.rules` (allows signed-in users on `inspections/{id}` and its `photos` subcollection). Deploy with:
```bash
firebase deploy --only firestore:rules --project fieldnote-5801c
```
Tighten to per-user ownership (`ownerUid` field) before any real use.

## Note on identifiers
The app currently uses the template IDs `com.example.field_note` (Android) / `com.example.fieldNote` (iOS). Rename before publishing and update `.env` with the new app IDs/keys.
