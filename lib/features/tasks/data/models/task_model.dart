import '../../domain/entities/priority.dart';
import '../../domain/entities/task.dart';

abstract final class TaskModel {
  static Task fromMap(Map<String, Object?> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      priority: Priority.values.firstWhere(
        (p) => p.name == map['priority'],
        orElse: () => Priority.medium,
      ),
      isCompleted: (map['is_completed'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
        isUtc: true,
      ),
    );
  }

  static Map<String, Object?> toMap(Task task) {
    return {
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'priority': task.priority.name,
      'is_completed': task.isCompleted ? 1 : 0,
      'created_at': task.createdAt.toUtc().millisecondsSinceEpoch,
    };
  }
}
