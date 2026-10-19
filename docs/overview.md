# Product Overview

FieldNote is an offline-first inspection app for technicians and field workers who inspect buildings, equipment or facilities where connectivity is poor or absent.

## Goals
- Complete inspection forms with **no network**.
- Attach **photos** and **GPS coordinates** to each inspection.
- **Sync automatically** when the connection returns, with no user action.
- Never lose data: the local database is the source of truth until a record is confirmed synced.

## Non-goals
Multi-tenant admin dashboards, user roles, conflict-resolution UI, form builders. This is a portfolio-scale app; keep it small.

## What it demonstrates
Offline-first architecture, local storage (SQLite), a sync engine (outbox pattern, retries, idempotency), background work, and Firebase as the remote backend.

## Users and flow
1. Technician opens the app, sees a list of inspections with a sync badge on each (pending / synced / failed).
2. Taps **New inspection**, fills the form (title, site, checklist items, pass/fail, notes), attaches photos, and captures GPS.
3. Saves. The record is written to SQLite immediately and queued for sync.
4. When the device is online, the sync engine uploads photos (compressed, into a Firestore subcollection) and the record to Firestore, then marks the record synced.

## Screens
| Screen | Purpose |
|---|---|
| Inspection list | All local inspections, sync status badges, pull-to-sync, offline banner |
| Inspection form | Create / edit an inspection: fields, checklist, photos, GPS |
| Inspection detail | Read-only view, photo gallery, map coordinates, sync state and last error |
| Sync status | Pending count, last sync time, manual "Sync now", failed items with retry |

## Inspection fields
- `title`, `siteName`, `category` (building / equipment / facility)
- `checklist`: list of `{label, result: pass | fail | n/a, note}`
- `overallStatus`: pass / fail / needs-attention
- `notes`
- `photos`: 0..n
- `latitude`, `longitude`, `accuracyMeters`, `capturedAt`
