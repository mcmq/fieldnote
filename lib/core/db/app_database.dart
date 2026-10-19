import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens the local SQLite database (the app's source of truth).
class AppDatabase {
  static const _version = 1;

  /// Pass [path] = [inMemoryDatabasePath] and a custom [factory] in tests.
  static Future<Database> open({String? path, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), 'fieldnote.db');
    return f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _create,
      ),
    );
  }

  static Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE inspections (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        site_name TEXT NOT NULL,
        category TEXT NOT NULL,
        overall_status TEXT NOT NULL,
        notes TEXT,
        latitude REAL, longitude REAL, accuracy_m REAL,
        captured_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0,
        sync_state TEXT NOT NULL DEFAULT 'pending'
      )''');
    await db.execute('''
      CREATE TABLE checklist_items (
        id TEXT PRIMARY KEY,
        inspection_id TEXT NOT NULL REFERENCES inspections(id) ON DELETE CASCADE,
        label TEXT NOT NULL,
        result TEXT NOT NULL,
        note TEXT,
        position INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE photos (
        id TEXT PRIMARY KEY,
        inspection_id TEXT NOT NULL REFERENCES inspections(id) ON DELETE CASCADE,
        local_path TEXT NOT NULL,
        remote_url TEXT,
        uploaded INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE outbox (
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        inspection_id TEXT NOT NULL,
        op TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at INTEGER NOT NULL
      )''');
  }
}
