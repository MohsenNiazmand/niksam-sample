import 'package:sqflite/sqflite.dart';

typedef Migration = Future<void> Function(DatabaseExecutor db);

Future<void> _v1(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE tasks(
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL CHECK(length(trim(title)) > 0),
      description TEXT NOT NULL DEFAULT '',
      priority TEXT NOT NULL CHECK(priority IN ('low','medium','high')),
      is_completed INTEGER NOT NULL DEFAULT 0 CHECK(is_completed IN (0,1)),
      created_at INTEGER NOT NULL
    );
  ''');

  await db.execute('''
    CREATE TABLE task_events(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
      type TEXT NOT NULL CHECK(type IN ('created','priority_changed','completed','reopened')),
      from_priority TEXT,
      to_priority TEXT,
      occurred_at INTEGER NOT NULL
    );
  ''');

  await db.execute('CREATE INDEX idx_events_task ON task_events(task_id, occurred_at, id);');
  await db.execute('CREATE INDEX idx_tasks_created ON tasks(created_at DESC);');
}

final List<Migration> kMigrations = [_v1];
int get schemaVersion => kMigrations.length;
