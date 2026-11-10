import 'package:niksam/features/tasks/domain/entities/priority.dart';
import 'package:niksam/features/tasks/domain/entities/task_event.dart';

abstract final class TaskEventModel {
  static TaskEvent fromMap(Map<String, Object?> map) {
    final type = map['type'] as String;
    final TaskEventKind kind;

    switch (type) {
      case 'created':
        kind = const TaskCreated();
        break;
      case 'priority_changed':
        final fromName = map['from_priority'] as String;
        final toName = map['to_priority'] as String;
        final from = Priority.values.firstWhere((p) => p.name == fromName);
        final to = Priority.values.firstWhere((p) => p.name == toName);
        kind = TaskPriorityChanged(from: from, to: to);
        break;
      case 'completed':
        kind = const TaskCompleted();
        break;
      case 'reopened':
        kind = const TaskReopened();
        break;
      default:
        throw ArgumentError('Unknown task event type: $type');
    }

    return TaskEvent(
      id: map['id'] as int,
      taskId: map['task_id'] as String,
      at: DateTime.fromMillisecondsSinceEpoch(
        map['occurred_at'] as int,
        isUtc: true,
      ),
      kind: kind,
    );
  }

  static Map<String, Object?> toMap({
    int? id,
    required String taskId,
    required DateTime at,
    required TaskEventKind kind,
  }) {
    final map = <String, Object?>{
      'task_id': taskId,
      'occurred_at': at.toUtc().millisecondsSinceEpoch,
    };
    if (id != null) {
      map['id'] = id;
    }

    switch (kind) {
      case TaskCreated():
        map['type'] = 'created';
        map['from_priority'] = null;
        map['to_priority'] = null;
        break;
      case TaskPriorityChanged(:final from, :final to):
        map['type'] = 'priority_changed';
        map['from_priority'] = from.name;
        map['to_priority'] = to.name;
        break;
      case TaskCompleted():
        map['type'] = 'completed';
        map['from_priority'] = null;
        map['to_priority'] = null;
        break;
      case TaskReopened():
        map['type'] = 'reopened';
        map['from_priority'] = null;
        map['to_priority'] = null;
        break;
    }

    return map;
  }
}
