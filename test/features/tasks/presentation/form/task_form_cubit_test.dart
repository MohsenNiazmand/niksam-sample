import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:niksam/core/error/failures.dart';
import 'package:niksam/core/utils/result.dart';
import 'package:niksam/features/tasks/domain/entities/priority.dart';
import 'package:niksam/features/tasks/domain/entities/task.dart';
import 'package:niksam/features/tasks/domain/entities/task_draft.dart';
import 'package:niksam/features/tasks/domain/logic/task_validator.dart';
import 'package:niksam/features/tasks/presentation/form/cubit/task_form_cubit.dart';
import 'package:niksam/features/tasks/presentation/form/cubit/task_form_state.dart';
import '../../../../support/fake_task_repository.dart';

void main() {
  group('TaskFormCubit tests (P5)', () {
    test('empty or whitespace title produces titleError and repo is never called', () async {
      final fakeRepo = FakeTaskRepository();
      final cubit = TaskFormCubit(fakeRepo);

      await cubit.submit('   ', 'description');

      expect(cubit.state.titleError, equals(TitleError.empty));
      expect(cubit.state.status, equals(FormStatus.editing));
      expect(fakeRepo.storedTasks, isEmpty);

      // editing title clears error
      cubit.titleEdited();
      expect(cubit.state.titleError, isNull);

      await cubit.close();
    });

    test('valid create: repo called with same id on retry after failure', () async {
      var attempt = 0;
      final testRepo = _ControllableCreateRepo(
        onCreate: (id, draft) async {
          attempt++;
          if (attempt == 1) {
            return const Failed(StorageFailure('Simulated failure'));
          }
          return Success(
            Task(
              id: id,
              title: draft.title,
              description: draft.description,
              priority: draft.priority,
              isCompleted: false,
              createdAt: DateTime.now().toUtc(),
            ),
          );
        },
      );

      final failingCubit = TaskFormCubit(testRepo);
      final id = failingCubit.state.taskId;
      expect(id, isNotEmpty);

      // First submit fails
      await failingCubit.submit('Title', 'Desc');
      expect(failingCubit.state.status, equals(FormStatus.failure));
      expect(failingCubit.state.taskId, equals(id));
      expect(failingCubit.state.token, equals(1));

      // Retry reuses the same id
      await failingCubit.submit('Title', 'Desc');
      expect(failingCubit.state.status, equals(FormStatus.success));
      expect(failingCubit.state.taskId, equals(id));

      await failingCubit.close();
    });

    test('double submit while submitting results in only one repo call', () async {
      final completer = Completer<Result<Task>>();
      var callCount = 0;

      final testRepo = _ControllableCreateRepo(
        onCreate: (id, draft) {
          callCount++;
          return completer.future;
        },
      );

      final cubit = TaskFormCubit(testRepo);

      // Start first submit (in-flight)
      final future1 = cubit.submit('Title', 'Desc');
      // Second submit immediately
      final future2 = cubit.submit('Title', 'Desc');

      expect(cubit.state.status, equals(FormStatus.submitting));

      completer.complete(
        Success(
          Task(
            id: cubit.state.taskId,
            title: 'Title',
            description: 'Desc',
            priority: Priority.medium,
            isCompleted: false,
            createdAt: DateTime.now().toUtc(),
          ),
        ),
      );

      await Future.wait([future1, future2]);

      expect(callCount, equals(1));
      expect(cubit.state.status, equals(FormStatus.success));

      await cubit.close();
    });

    test('edit with no change returns success and unchanged outcome', () async {
      final original = Task(
        id: 'edit-1',
        title: 'Original Title',
        description: 'Original Desc',
        priority: Priority.high,
        isCompleted: false,
        createdAt: DateTime.utc(2026, 11, 10),
      );

      final fakeRepo = FakeTaskRepository(tasks: [original]);
      final cubit = TaskFormCubit(fakeRepo, original: original);

      expect(cubit.state.mode, equals(FormMode.edit));
      expect(cubit.state.taskId, equals('edit-1'));
      expect(cubit.state.priority, equals(Priority.high));

      await cubit.submit('Original Title', 'Original Desc');

      expect(cubit.state.status, equals(FormStatus.success));

      await cubit.close();
    });
  });
}

class _ControllableCreateRepo extends FakeTaskRepository {
  final Future<Result<Task>> Function(String id, TaskDraft draft) onCreate;

  _ControllableCreateRepo({required this.onCreate});

  @override
  Future<Result<Task>> create(String id, TaskDraft draft) {
    return onCreate(id, draft);
  }
}
