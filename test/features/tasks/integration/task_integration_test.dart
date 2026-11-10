import 'package:flutter_test/flutter_test.dart';
import 'package:niksam/features/tasks/data/database/app_database.dart';
import 'package:niksam/features/tasks/data/datasources/task_local_datasource.dart';
import '../../../support/test_fault_injector.dart';
import 'package:niksam/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:niksam/features/tasks/domain/entities/priority.dart';
import 'package:niksam/features/tasks/domain/entities/task_draft.dart';
import 'package:niksam/features/tasks/domain/entities/task_event.dart';
import 'package:niksam/features/tasks/presentation/list/bloc/task_list_bloc.dart';
import 'package:niksam/features/tasks/presentation/list/bloc/task_list_event.dart';
import 'package:niksam/features/tasks/presentation/list/bloc/task_list_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('P7: Real SQLite + Repository + Bloc Integration Tests', () {
    late AppDatabase appDb;
    late TestFaultInjector faultInjector;
    late TaskLocalDataSource dataSource;
    late TaskRepositoryImpl repo;
    late TaskListBloc bloc;

    setUp(() async {
      appDb = AppDatabase(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      faultInjector = TestFaultInjector();
      dataSource = TaskLocalDataSource(
        database: appDb,
        faultInjector: faultInjector,
      );
      repo = TaskRepositoryImpl(dataSource: dataSource);
      bloc = TaskListBloc(repo);
    });

    tearDown(() async {
      await bloc.close();
      await repo.dispose();
    });

    test(
      '10 rapid TaskCompletionSetRequested(id, true) results in exactly 1 Completed event in SQLite',
      () async {
        // 1. Create a task directly via repo
        const taskId = 'task-rapid-1';
        await repo.create(
          taskId,
          const TaskDraft(
            title: 'Rapid Taps Task',
            description: '',
            priority: Priority.medium,
          ),
        );

        // Start the bloc and wait for initial load
        bloc.add(const TaskListStarted());
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // 2. Dispatch 10 rapid complete requests to the bloc
        for (var i = 0; i < 10; i++) {
          bloc.add(const TaskCompletionSetRequested(taskId, true));
        }

        // Wait for sequential mutations to drain and list reload to complete
        await Future<void>.delayed(const Duration(milliseconds: 300));

        expect(bloc.state.status, equals(TaskListStatus.success));
        expect(bloc.state.tasks.first.isCompleted, isTrue);

        // Verify the events in the real SQLite database
        final timelineRes = await repo.getTimeline(taskId);
        final events = timelineRes.dataOrNull ?? [];

        expect(events.length, equals(2)); // [Created, Completed]
        expect(events[0].kind, isA<TaskCreated>());
        expect(events[1].kind, isA<TaskCompleted>());
      },
    );

    test(
      'Fault injection: failure preserves stored state, retry succeeds and writes exactly one event',
      () async {
        const taskId = 'task-fault-1';
        await repo.create(
          taskId,
          const TaskDraft(
            title: 'Fault Retry Task',
            description: '',
            priority: Priority.low,
          ),
        );

        bloc.add(const TaskListStarted());
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // 1. Force write to fail mid-transaction
        faultInjector.failAtCheckpoints.add('after_task_write');

        const completeEvent = TaskCompletionSetRequested(taskId, true);
        bloc.add(completeEvent);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Bloc state should show actionFailure with retryEvent, stored state preserved (not completed)
        expect(bloc.state.actionFailure, isNotNull);
        expect(bloc.state.actionFailure!.retryEvent, equals(completeEvent));
        expect(bloc.state.tasks.first.isCompleted, isFalse);

        // Verify DB timeline still has only [Created]
        var timelineRes = await repo.getTimeline(taskId);
        expect(timelineRes.dataOrNull?.length, equals(1));
        expect(timelineRes.dataOrNull?.first.kind, isA<TaskCreated>());

        // 2. Clear fault and dispatch retryEvent
        faultInjector.failAtCheckpoints.clear();
        bloc.add(bloc.state.actionFailure!.retryEvent);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Verify it succeeded
        expect(bloc.state.tasks.first.isCompleted, isTrue);
        expect(bloc.state.actionFailure, isNull);

        // Verify timeline in SQLite now has exactly 2 events: [Created, Completed]
        timelineRes = await repo.getTimeline(taskId);
        final events = timelineRes.dataOrNull ?? [];
        expect(events.length, equals(2));
        expect(events[0].kind, isA<TaskCreated>());
        expect(events[1].kind, isA<TaskCompleted>());
      },
    );
  });
}

extension on dynamic {
  List<TaskEvent>? get dataOrNull {
    try {
      return (this as dynamic).data as List<TaskEvent>;
    } catch (_) {
      return null;
    }
  }
}
