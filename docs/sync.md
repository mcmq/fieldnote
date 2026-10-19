# Sync Engine

## Triggers
1. App start and app resume.
2. `connectivity_plus` reports a transition from offline to online.
3. After every local save (if online).
4. Periodic `workmanager` task (network-connected constraint) when the app is closed.
5. Manual "Sync now" on the Sync status screen.

Runs are serialized: a single in-flight guard prevents overlapping syncs.

## Algorithm (push)
```
for entry in outbox ORDER BY seq:
  load inspection + photos from SQLite
  if op == delete:
      set Firestore doc deleted=true; remove outbox entry
  else:
      for photo in photos where uploaded == 0:
          write base64 photo doc to Firestore -> remote_url = doc path; mark uploaded
      set Firestore doc inspections/{id} (full document, merge: false)
      sync_state = synced; remove outbox entry
  on error:
      attempts++, last_error = e, sync_state = failed
      stop on network errors (retry next trigger); continue on permanent errors
```

## Guarantees
- **Idempotent**: doc id is the client UUID; photo upload paths are deterministic; re-running a step is safe.
- **Resumable**: photo upload progress is tracked per photo, so a dropped connection mid-sync resumes where it stopped.
- **No data loss**: rows are never deleted locally until the remote write succeeds (soft delete).
- **Retry**: each outbox entry is retried automatically up to 5 times (one attempt per sync trigger); after that it stays `failed` until the user taps *Sync now*, which resets attempts. Network errors never consume attempts.

## Pull (optional, phase 2)
Fetch documents with `updatedAt` greater than the stored `last_pull_at`; apply when remote `updatedAt` > local and the local row has no pending outbox entry. Conflict policy: last-write-wins.

## Firebase offline persistence
Firestore's own offline cache is **disabled** (`persistenceEnabled: false`) so that the app's SQLite outbox is the single, explainable sync mechanism.
