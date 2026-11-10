import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niksam/core/error/failures.dart';
import 'package:niksam/core/utils/result.dart';
import 'package:niksam/features/tasks/domain/entities/priority.dart';
import 'package:niksam/features/tasks/domain/entities/task.dart';
import 'package:niksam/features/tasks/domain/entities/write_outcome.dart';
import 'package:niksam/features/tasks/presentation/list/bloc/task_list_bloc.dart';
import 'package:niksam/features/tasks/presentation/list/bloc/task_list_event.dart';
import 'package:niksam/features/tasks/presentation/list/bloc/task_list_state.dart';
import '../../../../support/fake_task_repository.dart';

void main() {
  final sampleTaskA = Task(
    id: '1',
    title: 'apple',
    description: '',
    priority: Priority.low,
    isCompleted: false,
    createdAt: DateTime.utc(2026, 11, 10),
  );

  final sampleTaskB = Task(
    id: '2',
    title: 'banana',
    description: '',
    priority: Priority.high,
    isCompleted: false,
    createdAt: DateTime.utc(2026, 11, 10),
  );

  group('TaskListBloc tests (P4)', () {
    test(
      '1. Stale query: slow earlier query completed after fast later query does not overwrite',
      () async {
        final fakeRepo = FakeTaskRepository(tasks: [sampleTaskA, sampleTaskB]);
        final bloc = TaskListBloc(fakeRepo);

        final completerA = Completer<Result<List<Task>>>();
        fakeRepo.nextGetTasksCompleter = completerA;

        // Start search 'a' (will hang on completerA)
        bloc.add(const TaskListSearchChanged('a'));
        await Future<void>.delayed(const Duration(milliseconds: 350));

        // Now start search 'banana' (fast)
        bloc.add(const TaskListSearchChanged('banana'));
        await Future<void>.delayed(const Duration(milliseconds: 350));

        expect(bloc.state.query.text, equals('banana'));
        expect(bloc.state.tasks, equals([sampleTaskB]));

        // Now complete the slow query 'a'
        completerA.complete(Success([sampleTaskA]));
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // State should still have 'banana' query and results
        expect(bloc.state.query.text, equals('banana'));
        expect(bloc.state.tasks, equals([sampleTaskB]));

        await bloc.close();
      },
    );

    test(
      '2. Cross-type staleness: search in flight, then priority filter changes',
      () async {
        final fakeRepo = FakeTaskRepository(tasks: [sampleTaskA, sampleTaskB]);
        final bloc = TaskListBloc(fakeRepo);

        final searchCompleter = Completer<Result<List<Task>>>();
        fakeRepo.nextGetTasksCompleter = searchCompleter;

        bloc.add(const TaskListSearchChanged('a'));
        await Future<void>.delayed(const Duration(milliseconds: 350));

        // Now change priority filter while search is in-flight
        bloc.add(const TaskListPriorityChanged(Priority.high));
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Complete search query afterwards
        searchCompleter.complete(Success([sampleTaskA]));
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(bloc.state.query.priority, equals(Priority.high));
        expect(bloc.state.tasks, equals([sampleTaskB]));

        await bloc.close();
      },
    );

    test(
      '3. Debounce: 5 rapid SearchChanged within 300ms executes repo query once with last text',
      () async {
        final fakeRepo = FakeTaskRepository(tasks: [sampleTaskA, sampleTaskB]);
        final bloc = TaskListBloc(fakeRepo);

        fakeRepo.getTasksHistory.clear();

        bloc.add(const TaskListSearchChanged('a'));
        bloc.add(const TaskListSearchChanged('ap'));
        bloc.add(const TaskListSearchChanged('app'));
        bloc.add(const TaskListSearchChanged('appl'));
        bloc.add(const TaskListSearchChanged('apple'));

        // Wait for debounce period (300ms + buffer)
        await Future<void>.delayed(const Duration(milliseconds: 400));

        expect(fakeRepo.getTasksHistory.length, equals(1));
        expect(fakeRepo.getTasksHistory.first.text, equals('apple'));

        await bloc.close();
      },
    );

    test(
      '4. Rapid same-target taps: 5 sequential completion requests run one at a time',
      () async {
        final fakeRepo = FakeTaskRepository(tasks: [sampleTaskA]);
        final bloc = TaskListBloc(fakeRepo);

        bloc.add(const TaskCompletionSetRequested('1', true));
        bloc.add(const TaskCompletionSetRequested('1', true));
        bloc.add(const TaskCompletionSetRequested('1', true));
        bloc.add(const TaskCompletionSetRequested('1', true));
        bloc.add(const TaskCompletionSetRequested('1', true));

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(fakeRepo.maxConcurrentMutations, equals(1));

        await bloc.close();
      },
    );

    test(
      '5. Failure path: action failure sets retryEvent, incrementing token, and reloads state',
      () async {
        final fakeRepo = FakeTaskRepository(tasks: [sampleTaskA]);
        final bloc = TaskListBloc(fakeRepo);

        fakeRepo.nextSetCompletedResult = const Failed<WriteOutcome>(
          StorageFailure('Disk write failed'),
        );

        const event = TaskCompletionSetRequested('1', true);
        bloc.add(event);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(bloc.state.actionFailure, isNotNull);
        expect(bloc.state.actionFailure!.message, equals('Disk write failed'));
        expect(bloc.state.actionFailure!.retryEvent, equals(event));
        final firstToken = bloc.state.actionFailure!.token;

        // Trigger identical failure again
        fakeRepo.nextSetCompletedResult = const Failed<WriteOutcome>(
          StorageFailure('Disk write failed'),
        );
        bloc.add(bloc.state.actionFailure!.retryEvent!);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(bloc.state.actionFailure, isNotNull);
        expect(bloc.state.actionFailure!.token, isNot(equals(firstToken)));

        await bloc.close();
      },
    );

    test(
      '6. Changes stream triggers reload with current query and close cancels it',
      () async {
        final fakeRepo = FakeTaskRepository(tasks: [sampleTaskA]);
        final bloc = TaskListBloc(fakeRepo);

        bloc.add(const TaskListPriorityChanged(Priority.low));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(bloc.state.query.priority, equals(Priority.low));

        fakeRepo.getTasksHistory.clear();
        fakeRepo.emitChange();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(fakeRepo.getTasksHistory.length, equals(1));
        expect(fakeRepo.getTasksHistory.first.priority, equals(Priority.low));

        await bloc.close();

        fakeRepo.getTasksHistory.clear();
        fakeRepo.emitChange();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(fakeRepo.getTasksHistory, isEmpty);
      },
    );

    blocTest<TaskListBloc, TaskListState>(
      '7. Initial load failure leads to failure status, then Reload recovers',
      build: () {
        final fakeRepo = FakeTaskRepository();
        fakeRepo.nextGetTasksResult = const Failed<List<Task>>(
          StorageFailure('DB busy'),
        );
        return TaskListBloc(fakeRepo);
      },
      act: (bloc) async {
        bloc.add(const TaskListStarted());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const TaskListReloadRequested());
      },
      expect: () => [
        const TaskListState(status: TaskListStatus.loading),
        const TaskListState(
          status: TaskListStatus.failure,
          loadFailure: StorageFailure('DB busy'),
        ),
        const TaskListState(
          status: TaskListStatus.loading,
          loadFailure: StorageFailure('DB busy'),
        ),
        const TaskListState(status: TaskListStatus.success, tasks: []),
      ],
    );
  });
}
