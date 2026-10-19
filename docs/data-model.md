# Data Model

## SQLite schema
```sql
CREATE TABLE inspections (
  id TEXT PRIMARY KEY,            -- client UUID v4
  title TEXT NOT NULL,
  site_name TEXT NOT NULL,
  category TEXT NOT NULL,         -- building | equipment | facility
  overall_status TEXT NOT NULL,   -- pass | fail | attention
  notes TEXT,
  latitude REAL, longitude REAL, accuracy_m REAL,
  captured_at INTEGER,            -- epoch ms
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0,   -- soft delete so deletions can sync
  sync_state TEXT NOT NULL DEFAULT 'pending'  -- pending | synced | failed
);

CREATE TABLE checklist_items (
  id TEXT PRIMARY KEY,
  inspection_id TEXT NOT NULL REFERENCES inspections(id) ON DELETE CASCADE,
  label TEXT NOT NULL,
  result TEXT NOT NULL,           -- pass | fail | na
  note TEXT,
  position INTEGER NOT NULL
);

CREATE TABLE photos (
  id TEXT PRIMARY KEY,
  inspection_id TEXT NOT NULL REFERENCES inspections(id) ON DELETE CASCADE,
  local_path TEXT NOT NULL,       -- file name only; see PhotoStore
  remote_url TEXT,                -- set after upload
  uploaded INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE outbox (
  seq INTEGER PRIMARY KEY AUTOINCREMENT,
  inspection_id TEXT NOT NULL,
  op TEXT NOT NULL,               -- upsert | delete
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  created_at INTEGER NOT NULL
);
```

## Firestore
Collection `inspections/{id}` mirrors the row; checklist items are embedded as an array, photos as an array of download URLs.

```json
{
  "title": "Boiler room A",
  "siteName": "Plant 2",
  "category": "equipment",
  "overallStatus": "attention",
  "notes": "...",
  "location": { "lat": 0.0, "lng": 0.0, "accuracyM": 5.0 },
  "checklist": [{ "label": "Pressure gauge", "result": "pass", "note": "" }],
  "photos": ["https://..."],
  "createdAt": "<timestamp>",
  "updatedAt": "<timestamp>",
  "deleted": false
}
```

Photos: `inspections/{inspectionId}/photos/{photoId}` with `{ data: <base64 JPEG>, bytes, createdAt }`. The inspection document's `photos` array holds these document paths. Photos are capped at 700 KB (Firestore's document limit is 1 MiB); `compressPhoto` re-encodes at capture to max 1024px, JPEG quality 60.
