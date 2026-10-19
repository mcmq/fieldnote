# Development Guide

## Prerequisites
Flutter (stable, Dart ^3.9), Xcode or Android Studio, Firebase CLI.

## First-time setup
```bash
cp .env.example .env   # fill in Firebase values; see docs/firebase.md
```

## Commands
```bash
flutter pub get
flutter run                 # pick a device/simulator
flutter analyze
flutter test
```

## Planned dependencies
`sqflite`, `path`, `path_provider`, `uuid`, `provider`, `connectivity_plus`, `workmanager`, `image_picker`, `image` (JPEG re-encoding), `geolocator`, plus the Firebase packages already added (`firebase_core`, `cloud_firestore`, `firebase_auth`).

## Platform permissions
- Android: `CAMERA`, `ACCESS_FINE_LOCATION`, `INTERNET`, `ACCESS_NETWORK_STATE`.
- iOS `Info.plist`: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSLocationWhenInUseUsageDescription`.

## Testing offline behaviour
- Airplane mode on the device/simulator, create inspections, then disable it and watch badges flip to *synced*.
- Unit-test the repository and `SyncEngine` with an in-memory SQLite (`sqflite_common_ffi`) and a fake remote gateway.

## Roadmap
1. [ ] DB layer + repository + models
2. [ ] Inspection list and form screens
3. [ ] Photo capture and GPS
4. [ ] Sync engine + connectivity trigger
5. [ ] Background sync (workmanager)
6. [ ] Sync status screen
7. [ ] Tests, screenshots, polish
8. [ ] (Optional) pull sync
