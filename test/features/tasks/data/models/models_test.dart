import 'package:flutter_test/flutter_test.dart';
import 'package:niksam/features/tasks/domain/entities/priority.dart';
import 'package:niksam/features/tasks/domain/entities/task.dart';
import 'package:niksam/features/tasks/domain/entities/task_event.dart';
import 'package:niksam/features/tasks/data/models/task_model.dart';
import 'package:niksam/features/tasks/data/models/task_event_model.dart';

void main() {
  group('TaskModel', () {
    test('toMap and fromMap roundtrip correctly', () {
      final task = Task(
        id: 'uuid-1',
        title: 'Task title',
        description: 'Task desc',
        priority: Priority.high,
        isCompleted: true,
        createdAt: DateTime.utc(2026, 11, 10, 12, 30),
      );

      final map = TaskModel.toMap(task);
      expect(map['id'], 'uuid-1');
      expect(map['title'], 'Task title');
      expect(map['description'], 'Task desc');
      expect(map['priority'], 'high');
      expect(map['is_completed'], 1);
      expect(map['created_at'], task.createdAt.millisecondsSinceEpoch);

      final recovered = TaskModel.fromMap(map);
      expect(recovered, equals(task));
    });

    test('corrupt priority throws ArgumentError', () {
      final map = {
        'id': 'uuid-2',
        'title': 'Corrupt priority',
        'description': '',
        'priority': 'unknown_priority',
        'is_completed': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

      expect(() => TaskModel.fromMap(map), throwsA(isA<ArgumentError>()));
    });
  });

  group('TaskEventModel', () {
    final at = DateTime.utc(2026, 11, 10, 14, 0);

    test('roundtrip created event', () {
      final event = TaskEvent(
        id: 1,
        taskId: 't-1',
        at: at,
        kind: const TaskCreated(),
      );

      final map = TaskEventModel.toMap(
        id: event.id,
        taskId: event.taskId,
        at: event.at,
        kind: event.kind,
      );

      final recovered = TaskEventModel.fromMap(map);
      expect(recovered, equals(event));
    });

    test('roundtrip priority_changed event', () {
      final event = TaskEvent(
        id: 2,
        taskId: 't-1',
        at: at,
        kind: const TaskPriorityChanged(from: Priority.low, to: Priority.high),
      );

      final map = TaskEventModel.toMap(
        id: event.id,
        taskId: event.taskId,
        at: event.at,
        kind: event.kind,
      );

      expect(map['from_priority'], 'low');
      expect(map['to_priority'], 'high');

      final recovered = TaskEventModel.fromMap(map);
      expect(recovered, equals(event));
    });

    test('roundtrip completed and reopened events', () {
      final completedEvent = TaskEvent(
        id: 3,
        taskId: 't-1',
        at: at,
        kind: const TaskCompleted(),
      );
      final completedMap = TaskEventModel.toMap(
        id: completedEvent.id,
        taskId: completedEvent.taskId,
        at: completedEvent.at,
        kind: completedEvent.kind,
      );
      expect(TaskEventModel.fromMap(completedMap), equals(completedEvent));

      final reopenedEvent = TaskEvent(
        id: 4,
        taskId: 't-1',
        at: at,
        kind: const TaskReopened(),
      );
      final reopenedMap = TaskEventModel.toMap(
        id: reopenedEvent.id,
        taskId: reopenedEvent.taskId,
        at: reopenedEvent.at,
        kind: reopenedEvent.kind,
      );
      expect(TaskEventModel.fromMap(reopenedMap), equals(reopenedEvent));
    });
  });
}
