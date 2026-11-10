import 'package:flutter_test/flutter_test.dart';
import 'package:niksam/features/tasks/domain/entities/priority.dart';
import 'package:niksam/features/tasks/domain/entities/task.dart';
import 'package:niksam/features/tasks/domain/entities/task_draft.dart';
import 'package:niksam/features/tasks/domain/entities/task_event.dart';
import 'package:niksam/features/tasks/domain/logic/task_change_detector.dart';

void main() {
  group('TaskChangeDetector.hasChanges', () {
    final baseTask = Task(
      id: 'task-1',
      title: 'Buy milk',
      description: '2 cartons of whole milk',
      priority: Priority.medium,
      isCompleted: false,
      createdAt: DateTime.utc(2026, 11, 10, 10, 0),
    );

    test('returns false when draft is identical', () {
      final draft = TaskDraft(
        title: 'Buy milk',
        description: '2 cartons of whole milk',
        priority: Priority.medium,
      );
      expect(TaskChangeDetector.hasChanges(baseTask, draft), isFalse);
    });

    test('returns false when differences are only leading/trailing whitespace', () {
      final draft = TaskDraft(
        title: '  Buy milk  ',
        description: '  2 cartons of whole milk \n ',
        priority: Priority.medium,
      );
      expect(TaskChangeDetector.hasChanges(baseTask, draft), isFalse);
    });

    test('returns true when title changed', () {
      final draft = TaskDraft(
        title: 'Buy almond milk',
        description: '2 cartons of whole milk',
        priority: Priority.medium,
      );
      expect(TaskChangeDetector.hasChanges(baseTask, draft), isTrue);
    });

    test('returns true when description changed', () {
      final draft = TaskDraft(
        title: 'Buy milk',
        description: '3 cartons',
        priority: Priority.medium,
      );
      expect(TaskChangeDetector.hasChanges(baseTask, draft), isTrue);
    });

    test('returns true when priority changed', () {
      final draft = TaskDraft(
        title: 'Buy milk',
        description: '2 cartons of whole milk',
        priority: Priority.high,
      );
      expect(TaskChangeDetector.hasChanges(baseTask, draft), isTrue);
    });
  });

  group('TaskChangeDetector.eventsForUpdate', () {
    final baseTask = Task(
      id: 'task-1',
      title: 'Buy milk',
      description: '2 cartons of whole milk',
      priority: Priority.low,
      isCompleted: false,
      createdAt: DateTime.utc(2026, 11, 10, 10, 0),
    );

    test('returns PriorityChanged when priority changes', () {
      final draft = TaskDraft(
        title: 'Buy milk',
        description: '2 cartons of whole milk',
        priority: Priority.high,
      );
      final events = TaskChangeDetector.eventsForUpdate(baseTask, draft);
      expect(
        events,
        equals([const TaskPriorityChanged(from: Priority.low, to: Priority.high)]),
      );
    });

    test('returns empty list when only title or description changed', () {
      final draft = TaskDraft(
        title: 'Buy fresh milk',
        description: 'and eggs',
        priority: Priority.low,
      );
      final events = TaskChangeDetector.eventsForUpdate(baseTask, draft);
      expect(events, isEmpty);
    });

    test('returns empty list when unchanged', () {
      final draft = TaskDraft(
        title: 'Buy milk',
        description: '2 cartons of whole milk',
        priority: Priority.low,
      );
      final events = TaskChangeDetector.eventsForUpdate(baseTask, draft);
      expect(events, isEmpty);
    });
  });

  group('TaskChangeDetector.eventForCompletion', () {
    final openTask = Task(
      id: 'task-1',
      title: 'Task 1',
      description: '',
      priority: Priority.medium,
      isCompleted: false,
      createdAt: DateTime.utc(2026, 11, 10),
    );

    final completedTask = openTask.copyWith(isCompleted: true);

    test('returns Completed when transitioning from false to true', () {
      final event = TaskChangeDetector.eventForCompletion(openTask, true);
      expect(event, equals(const TaskCompleted()));
    });

    test('returns Reopened when transitioning from true to false', () {
      final event = TaskChangeDetector.eventForCompletion(completedTask, false);
      expect(event, equals(const TaskReopened()));
    });

    test('returns null if already completed and target is true', () {
      final event = TaskChangeDetector.eventForCompletion(completedTask, true);
      expect(event, isNull);
    });

    test('returns null if already open and target is false', () {
      final event = TaskChangeDetector.eventForCompletion(openTask, false);
      expect(event, isNull);
    });
  });
}
