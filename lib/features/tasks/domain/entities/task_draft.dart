import 'package:equatable/equatable.dart';
import 'priority.dart';

class TaskDraft extends Equatable {
  final String title;
  final String description;
  final Priority priority;

  const TaskDraft({
    required this.title,
    required this.description,
    required this.priority,
  });

  TaskDraft normalized() {
    final trimmedDesc = description.trim();
    return TaskDraft(
      title: title.trim(),
      description: trimmedDesc,
      priority: priority,
    );
  }

  @override
  List<Object?> get props => [title, description, priority];
}
