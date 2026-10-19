# Architecture

## Principle: local first
The UI only ever reads from and writes to SQLite. It never waits on the network. A separate sync engine reconciles SQLite with Firebase in the background.

```
 UI (screens, widgets)
        │  reads/writes
        ▼
 Repository  ───────────────►  SQLite (sqflite)   ← source of truth
        │ enqueues change              ▲
        ▼                              │ marks synced / failed
 Sync queue (outbox table)             │
        │                              │
        ▼                              │
 Sync engine ──── connectivity ────────┘
        │
        └─► Cloud Firestore   (inspections + photos subcollection)
```

## Layers
| Layer | Responsibility | Location |
|---|---|---|
| Presentation | Screens, widgets, state | `lib/features/*/presentation` |
| Domain | Models (`Inspection`, `ChecklistItem`, `Photo`) | `lib/features/*/domain` |
| Data | `InspectionRepository`, SQLite DAOs | `lib/features/*/data`, `lib/core/db` |
| Sync | `SyncEngine`, outbox, connectivity watcher, background task | `lib/core/sync` |
| Remote | Firestore gateway | `lib/core/remote` |
| Platform | GPS, camera, permissions | `lib/core/platform` |

## Key decisions
- **SQLite via `sqflite`** for local persistence; simple, mature, easy to explain.
- **Outbox pattern**: every create/update/delete writes the row *and* an outbox entry in one transaction. The engine drains the outbox in order.
- **Client-generated UUIDs** as primary keys, so records can be created offline and pushed idempotently (`set` on the same doc id never duplicates).
- **Photos stored on disk**, only the file name in SQLite (iOS app container paths change between installs, so absolute paths break; `PhotoStore` resolves names against `<documents>/photos`). Firebase Storage needs a paid plan, so each photo is re-encoded at capture by `compressPhoto` (max 1024px, JPEG quality 60) and stored as base64 in `inspections/{id}/photos/{photoId}` (Firestore 1 MiB doc limit; app rejects photos over 700 KB). Photos are written before the inspection document. For production, move this to object storage.
- **Last-write-wins** using `updatedAt`. No merge UI.
- **State management**: `provider` + `ChangeNotifier` (keep it simple).
- **Background sync**: `workmanager` periodic task with a network constraint, plus an in-app listener on `connectivity_plus` for immediate sync while the app is open.

## Folder layout (target)
```
lib/
  main.dart
  core/config/firebase_env.dart  # Firebase options built from .env
  core/{db,sync,remote,platform}/
  features/inspections/{domain,data,presentation}/
```
