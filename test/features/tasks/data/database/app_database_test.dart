import 'package:flutter_test/flutter_test.dart';
import 'package:niksam/features/tasks/data/database/app_database.dart';
import 'package:niksam/features/tasks/data/database/migrations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('AppDatabase', () {
    test(
      'fresh open sets schema version and enables foreign_keys pragma',
      () async {
        final appDb = AppDatabase(
          path: inMemoryDatabasePath,
          factory: databaseFactoryFfi,
        );

        final db = await appDb.database;

        final versionResult = await db.rawQuery('PRAGMA user_version');
        final version = versionResult.first.values.first as int;
        expect(version, equals(schemaVersion));

        final fkResult = await db.rawQuery('PRAGMA foreign_keys');
        final fk = fkResult.first.values.first as int;
        expect(fk, equals(1));

        await appDb.close();
      },
    );

    test('migration chain v0->v2 applies migrations in order', () async {
      final appliedMigrations = <int>[];

      final testMigrations = <Migration>[
        (db) async {
          appliedMigrations.add(1);
          await db.execute('CREATE TABLE t1 (id INTEGER PRIMARY KEY)');
        },
        (db) async {
          appliedMigrations.add(2);
          await db.execute('CREATE TABLE t2 (id INTEGER PRIMARY KEY)');
        },
      ];

      final appDb = AppDatabase(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
        migrations: testMigrations,
      );

      final db = await appDb.database;

      expect(appliedMigrations, equals([1, 2]));

      final versionResult = await db.rawQuery('PRAGMA user_version');
      expect(versionResult.first.values.first, equals(2));

      await appDb.close();
    });

    test('CHECK constraints reject invalid priority', () async {
      final appDb = AppDatabase(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );

      final db = await appDb.database;

      expect(
        () async => db.insert('tasks', {
          'id': 'task-invalid-priority',
          'title': 'Test task',
          'description': '',
          'priority':
              'critical', // Invalid priority! (must be low, medium, high)
          'is_completed': 0,
          'created_at': 1700000000,
        }),
        throwsA(isA<DatabaseException>()),
      );

      await appDb.close();
    });

    test('CHECK constraints reject empty title after trim', () async {
      final appDb = AppDatabase(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );

      final db = await appDb.database;

      expect(
        () async => db.insert('tasks', {
          'id': 'task-empty-title',
          'title': '   ',
          'description': '',
          'priority': 'low',
          'is_completed': 0,
          'created_at': 1700000000,
        }),
        throwsA(isA<DatabaseException>()),
      );

      await appDb.close();
    });
  });
}
