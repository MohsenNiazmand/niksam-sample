import 'package:flutter_test/flutter_test.dart';
import 'package:niksam/core/error/failures.dart';
import 'package:niksam/core/utils/result.dart';
import 'package:niksam/features/tasks/domain/entities/task_event.dart';
import 'package:niksam/features/tasks/presentation/timeline/cubit/task_timeline_cubit.dart';
import 'package:niksam/features/tasks/presentation/timeline/cubit/task_timeline_state.dart';
import '../../../../support/fake_task_repository.dart';

void main() {
  group('TaskTimelineCubit tests (P5)', () {
    test('load empty timeline', () async {
      final fakeRepo = FakeTaskRepository();
      final cubit = TaskTimelineCubit(fakeRepo, 't1');

      await cubit.load();

      expect(cubit.state.status, equals(TimelineStatus.success));
      expect(cubit.state.events, isEmpty);
      expect(cubit.state.isEmpty, isTrue);

      await cubit.close();
    });

    test('load populated timeline', () async {
      final event = TaskEvent(
        id: 1,
        taskId: 't1',
        at: DateTime.utc(2026, 11, 10),
        kind: const TaskCreated(),
      );
      final fakeRepo = FakeTaskRepository(events: [event]);
      final cubit = TaskTimelineCubit(fakeRepo, 't1');

      await cubit.load();

      expect(cubit.state.status, equals(TimelineStatus.success));
      expect(cubit.state.events, equals([event]));
      expect(cubit.state.isEmpty, isFalse);

      await cubit.close();
    });

    test('failure on load and recovery on retry', () async {
      var attempt = 0;
      final testRepo = _FailingTimelineRepo(
        onGetTimeline: (id) async {
          attempt++;
          if (attempt == 1) {
            return const Failed(StorageFailure('Timeline DB error'));
          }
          return Success([
            TaskEvent(
              id: 1,
              taskId: id,
              at: DateTime.utc(2026, 11, 10),
              kind: const TaskCreated(),
            ),
          ]);
        },
      );

      final cubit = TaskTimelineCubit(testRepo, 't1');

      // First attempt fails
      await cubit.load();
      expect(cubit.state.status, equals(TimelineStatus.failure));
      expect(
        cubit.state.failure,
        equals(const StorageFailure('Timeline DB error')),
      );

      // Retry recovers
      await cubit.load();
      expect(cubit.state.status, equals(TimelineStatus.success));
      expect(cubit.state.events.length, equals(1));

      await cubit.close();
    });
  });
}

class _FailingTimelineRepo extends FakeTaskRepository {
  final Future<Result<List<TaskEvent>>> Function(String taskId) onGetTimeline;

  _FailingTimelineRepo({required this.onGetTimeline});

  @override
  Future<Result<List<TaskEvent>>> getTimeline(String taskId) {
    return onGetTimeline(taskId);
  }
}
