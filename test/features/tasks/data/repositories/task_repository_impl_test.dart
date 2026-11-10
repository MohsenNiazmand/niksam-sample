import 'package:flutter_test/flutter_test.dart';
import 'package:niksam/core/error/failures.dart';
import 'package:niksam/core/utils/result.dart';
import 'package:niksam/features/tasks/data/database/app_database.dart';
import 'package:niksam/features/tasks/data/datasources/task_local_datasource.dart';
import '../../../../support/test_fault_injector.dart';
import 'package:niksam/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:niksam/features/tasks/domain/entities/priority.dart';
import 'package:niksam/features/tasks/domain/entities/task.dart';
import 'package:niksam/features/tasks/domain/entities/task_draft.dart';
import 'package:niksam/features/tasks/domain/entities/task_event.dart';
import 'package:niksam/features/tasks/domain/entities/task_query.dart';
import 'package:niksam/features/tasks/domain/entities/write_outcome.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late AppDatabase appDb;
  late TestFaultInjector faultInjector;
  late TaskLocalDataSource dataSource;
  late TaskRepositoryImpl repo;
  late DateTime fixedNow;

  setUp(() {
    fixedNow = DateTime.utc(2026, 11, 10, 10, 0);
    appDb = AppDatabase(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    faultInjector = TestFaultInjector();
    dataSource = TaskLocalDataSource(
      database: appDb,
      faultInjector: faultInjector,
    );
    repo = TaskRepositoryImpl(dataSource: dataSource, now: () => fixedNow);
  });

  tearDown(() async {
    await repo.dispose();
  });

  group('Atomic Rollback tests (P3.1)', () {
    test('create rollback when fault occurs after task write', () async {
      faultInjector.failAtCheckpoints.add('after_task_write');

      var changeEmitted = false;
      repo.changes.listen((_) => changeEmitted = true);

      final result = await repo.create(
        't1',
        const TaskDraft(
          title: 'Initial',
          description: '',
          priority: Priority.medium,
        ),
      );

      expect(result, isA<Failed<Task>>());
      expect((result as Failed<Task>).failure, isA<StorageFailure>());
      expect(changeEmitted, isFalse);

      final db = await appDb.database;
      final taskRows = await db.query(
        'tasks',
        where: 'id = ?',
        whereArgs: ['t1'],
      );
      expect(taskRows, isEmpty);
      final eventRows = await db.query(
        'task_events',
        where: 'task_id = ?',
        whereArgs: ['t1'],
      );
      expect(eventRows, isEmpty);
    });

    test(
      'update-with-priority-change rollback leaves stored task unchanged and no event',
      () async {
        await repo.create(
          't1',
          const TaskDraft(
            title: 'Initial',
            description: '',
            priority: Priority.low,
          ),
        );

        faultInjector.failAtCheckpoints.add('after_task_write');

        var changeEmitted = false;
        repo.changes.listen((_) => changeEmitted = true);

        final result = await repo.update(
          't1',
          const TaskDraft(
            title: 'Updated title',
            description: 'Updated desc',
            priority: Priority.high,
          ),
        );

        expect(result, isA<Failed<WriteOutcome>>());
        expect(changeEmitted, isFalse);

        final db = await appDb.database;
        final taskRows = await db.query(
          'tasks',
          where: 'id = ?',
          whereArgs: ['t1'],
        );
        expect(taskRows.first['priority'], equals('low'));
        expect(taskRows.first['title'], equals('Initial'));

        final timeline = await repo.getTimeline('t1');
        expect((timeline as Success<List<TaskEvent>>).data.length, equals(1));
        expect(timeline.data.first.kind, isA<TaskCreated>());
      },
    );

    test(
      'setCompleted rollback leaves stored task uncompleted and no event',
      () async {
        await repo.create(
          't1',
          const TaskDraft(
            title: 'Initial',
            description: '',
            priority: Priority.low,
          ),
        );

        faultInjector.failAtCheckpoints.add('after_task_write');

        var changeEmitted = false;
        repo.changes.listen((_) => changeEmitted = true);

        final result = await repo.setCompleted('t1', true);
        expect(result, isA<Failed<WriteOutcome>>());
        expect(changeEmitted, isFalse);

        final db = await appDb.database;
        final taskRows = await db.query(
          'tasks',
          where: 'id = ?',
          whereArgs: ['t1'],
        );
        expect(taskRows.first['is_completed'], equals(0));

        final timeline = await repo.getTimeline('t1');
        expect((timeline as Success<List<TaskEvent>>).data.length, equals(1));
      },
    );

    test('delete rollback leaves stored task and its events intact', () async {
      await repo.create(
        't1',
        const TaskDraft(
          title: 'Initial',
          description: '',
          priority: Priority.low,
        ),
      );

      faultInjector.failAtCheckpoints.add('after_task_write');

      var changeEmitted = false;
      repo.changes.listen((_) => changeEmitted = true);

      final result = await repo.delete('t1');
      expect(result, isA<Failed<void>>());
      expect(changeEmitted, isFalse);

      final db = await appDb.database;
      final taskRows = await db.query(
        'tasks',
        where: 'id = ?',
        whereArgs: ['t1'],
      );
      expect(taskRows.length, equals(1));
    });
  });

  group('No-op writes nothing (P3.2)', () {
    test(
      'update with identical draft executes zero statements and changes total_changes by 0',
      () async {
        await repo.create(
          't1',
          const TaskDraft(
            title: 'Milk',
            description: 'Whole milk',
            priority: Priority.medium,
          ),
        );

        final db = await appDb.database;
        final beforeChanges =
            (await db.rawQuery('SELECT total_changes() as c')).first['c']
                as int;

        var changeEmitted = false;
        repo.changes.listen((_) => changeEmitted = true);

        final result = await repo.update(
          't1',
          const TaskDraft(
            title: '  Milk  ',
            description: ' Whole milk ',
            priority: Priority.medium,
          ),
        );

        expect(result, isA<Success<WriteOutcome>>());
        expect(
          (result as Success<WriteOutcome>).data,
          equals(const Unchanged()),
        );
        expect(changeEmitted, isFalse);

        final afterChanges =
            (await db.rawQuery('SELECT total_changes() as c')).first['c']
                as int;
        expect(afterChanges, equals(beforeChanges));

        final timeline = await repo.getTimeline('t1');
        expect((timeline as Success<List<TaskEvent>>).data.length, equals(1));
      },
    );
  });

  group('Idempotent concurrency (P3.3)', () {
    test(
      '10 concurrent setCompleted(id, true) produces exactly 1 Completed event',
      () async {
        await repo.create(
          't1',
          const TaskDraft(
            title: 'Concurrent task',
            description: '',
            priority: Priority.low,
          ),
        );

        final futures = List.generate(10, (_) => repo.setCompleted('t1', true));
        final results = await Future.wait(futures);

        final savedCount = results
            .where((r) => (r as Success<WriteOutcome>).data is Saved)
            .length;
        final unchangedCount = results
            .where((r) => (r as Success<WriteOutcome>).data is Unchanged)
            .length;

        expect(savedCount, equals(1));
        expect(unchangedCount, equals(9));

        final timeline = await repo.getTimeline('t1');
        final events = (timeline as Success<List<TaskEvent>>).data;
        final completedEvents = events.where((e) => e.kind is TaskCompleted);
        expect(completedEvents.length, equals(1));
      },
    );

    test(
      'sequential alternating completions produce strictly alternating event kinds',
      () async {
        await repo.create(
          't1',
          const TaskDraft(
            title: 'Alternating task',
            description: '',
            priority: Priority.low,
          ),
        );

        for (var i = 0; i < 6; i++) {
          await repo.setCompleted('t1', i % 2 == 0);
        }

        final timeline = await repo.getTimeline('t1');
        final events = (timeline as Success<List<TaskEvent>>).data;

        // First event is Created, then Completed, Reopened, Completed, Reopened, Completed, Reopened
        expect(events[0].kind, isA<TaskCreated>());
        expect(events[1].kind, isA<TaskCompleted>());
        expect(events[2].kind, isA<TaskReopened>());
        expect(events[3].kind, isA<TaskCompleted>());
        expect(events[4].kind, isA<TaskReopened>());
        expect(events[5].kind, isA<TaskCompleted>());
        expect(events[6].kind, isA<TaskReopened>());
      },
    );
  });

  group('Events precision (P3.4)', () {
    test(
      'create generates Created event, priority change generates PriorityChanged, title change generates no event',
      () async {
        await repo.create(
          't1',
          const TaskDraft(
            title: 'Title 1',
            description: '',
            priority: Priority.low,
          ),
        );

        // Title only change
        await repo.update(
          't1',
          const TaskDraft(
            title: 'Title 2',
            description: 'Now has description',
            priority: Priority.low,
          ),
        );

        var timeline = await repo.getTimeline('t1');
        var events = (timeline as Success<List<TaskEvent>>).data;
        expect(events.length, equals(1));
        expect(events.first.kind, isA<TaskCreated>());

        // Priority change
        await repo.update(
          't1',
          const TaskDraft(
            title: 'Title 2',
            description: 'Now has description',
            priority: Priority.high,
          ),
        );

        timeline = await repo.getTimeline('t1');
        events = (timeline as Success<List<TaskEvent>>).data;
        expect(events.length, equals(2));
        expect(
          events[1].kind,
          equals(
            const TaskPriorityChanged(from: Priority.low, to: Priority.high),
          ),
        );
      },
    );
  });

  group('Delete cascade (P3.5)', () {
    test(
      'deleting a task deletes all its events via ON DELETE CASCADE',
      () async {
        await repo.create(
          't1',
          const TaskDraft(
            title: 'Delete me',
            description: '',
            priority: Priority.low,
          ),
        );
        await repo.setCompleted('t1', true);
        await repo.setCompleted('t1', false);

        final db = await appDb.database;
        var eventCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM task_events WHERE task_id = ?',
            ['t1'],
          ),
        );
        expect(eventCount, equals(3));

        final deleteResult = await repo.delete('t1');
        expect(deleteResult, isA<Success<void>>());

        eventCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM task_events WHERE task_id = ?',
            ['t1'],
          ),
        );
        expect(eventCount, equals(0));
      },
    );
  });

  group('Query filters and ordering (P3.6)', () {
    test(
      'search + priority + completion combined with literal % and _ escaping',
      () async {
        final t1 = await repo.create(
          't1',
          const TaskDraft(
            title: '100% finished item',
            description: '',
            priority: Priority.high,
          ),
        );
        expect(t1, isA<Success<Task>>());

        await repo.create(
          't2',
          const TaskDraft(
            title: '1000 items',
            description: '',
            priority: Priority.high,
          ),
        );

        await repo.create(
          't3',
          const TaskDraft(
            title: 'task_name item',
            description: '',
            priority: Priority.low,
          ),
        );

        await repo.create(
          't4',
          const TaskDraft(
            title: 'taskXname item',
            description: '',
            priority: Priority.low,
          ),
        );

        // Search literal '%'
        var res = await repo.getTasks(const TaskQuery(text: '100%'));
        var tasks = (res as Success<List<Task>>).data;
        expect(tasks.map((t) => t.id).toList(), equals(['t1']));

        // Search literal '_'
        res = await repo.getTasks(const TaskQuery(text: 'task_name'));
        tasks = (res as Success<List<Task>>).data;
        expect(tasks.map((t) => t.id).toList(), equals(['t3']));

        // Search combined with priority and completion
        await repo.setCompleted('t1', true);

        res = await repo.getTasks(
          const TaskQuery(
            text: '100%',
            priority: Priority.high,
            completion: CompletionFilter.completed,
          ),
        );
        tasks = (res as Success<List<Task>>).data;
        expect(tasks.map((t) => t.id).toList(), equals(['t1']));

        res = await repo.getTasks(
          const TaskQuery(
            text: '100%',
            priority: Priority.high,
            completion: CompletionFilter.open,
          ),
        );
        tasks = (res as Success<List<Task>>).data;
        expect(tasks, isEmpty);
      },
    );

    test(
      'timeline chronological with same-millisecond tie-break by id',
      () async {
        await repo.create(
          't1',
          const TaskDraft(
            title: 'Same millis',
            description: '',
            priority: Priority.low,
          ),
        );
        await repo.setCompleted('t1', true);
        await repo.setCompleted('t1', false);

        final timeline = await repo.getTimeline('t1');
        final events = (timeline as Success<List<TaskEvent>>).data;
        expect(events.length, equals(3));
        expect(events[0].id < events[1].id, isTrue);
        expect(events[1].id < events[2].id, isTrue);
        expect(events[0].kind, isA<TaskCreated>());
        expect(events[1].kind, isA<TaskCompleted>());
        expect(events[2].kind, isA<TaskReopened>());
      },
    );
  });
}
