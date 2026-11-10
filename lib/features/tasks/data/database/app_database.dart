import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'migrations.dart';

class AppDatabase {
  final String? path;
  final DatabaseFactory? factory;
  final List<Migration> migrations;

  Future<Database>? _dbFuture;

  AppDatabase({this.path, this.factory, List<Migration>? migrations})
    : migrations = migrations ?? kMigrations;

  Future<Database> get database {
    return _dbFuture ??= _open().catchError((Object e) {
      _dbFuture = null;
      throw e;
    });
  }

  Future<Database> _open() async {
    final f = factory ?? databaseFactory;
    final dbPath =
        path ?? p.join(await f.getDatabasesPath(), 'niksam_tasks.db');
    final version = migrations.length;

    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          for (var i = 0; i < version; i++) {
            await migrations[i](db);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          for (var i = oldVersion; i < newVersion; i++) {
            await migrations[i](db);
          }
        },
        onDowngrade: (db, oldVersion, newVersion) async {
          throw StateError(
            'Downgrade from version $oldVersion to $newVersion is not allowed to prevent data loss.',
          );
        },
      ),
    );
    return db;
  }

  Future<void> close() async {
    final future = _dbFuture;
    _dbFuture = null;
    if (future != null) {
      try {
        final db = await future;
        await db.close();
      } catch (_) {}
    }
  }
}
