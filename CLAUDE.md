# FieldNote

Offline-first Flutter inspection app (SQLite local store, Firebase sync). Small portfolio project; keep it simple.

## Docs (read before changing related code)
- [docs/overview.md](docs/overview.md) — product goals, screens, inspection fields
- [docs/architecture.md](docs/architecture.md) — layers, local-first design, folder layout
- [docs/data-model.md](docs/data-model.md) — SQLite schema and Firestore document shape
- [docs/sync.md](docs/sync.md) — outbox sync engine, triggers, retry rules
- [docs/firebase.md](docs/firebase.md) — project `fieldnote-5801c`, setup, security rules
- [docs/development.md](docs/development.md) — commands, permissions, testing, roadmap

## Rules
- The UI reads/writes **SQLite only**; never call Firestore from widgets. All remote access goes through `lib/core/sync` and `lib/core/remote`.
- Every write to an inspection must also write an outbox entry in the same transaction.
- IDs are client-generated UUIDs; deletes are soft (`deleted = 1`) so they can sync.
- Firestore's own offline persistence stays disabled; SQLite is the source of truth.
- Firebase config comes from `.env` (gitignored; template in `.env.example`) via `lib/core/config/firebase_env.dart`. Never commit `.env`, `google-services.json`, `GoogleService-Info.plist` or keys.
- If a change alters the schema, sync behaviour or architecture, update the matching doc in the same change.

## Commands
`flutter pub get` · `flutter run` · `flutter analyze` · `flutter test`

## Status
Implemented: local DB, repository, inspection screens, photos + GPS, outbox sync engine, workmanager background sync, tests. Pull sync is not implemented.
