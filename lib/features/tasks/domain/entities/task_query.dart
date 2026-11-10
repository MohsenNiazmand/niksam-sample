import 'package:equatable/equatable.dart';
import 'priority.dart';

enum CompletionFilter { all, open, completed }

class TaskQuery extends Equatable {
  final String text;
  final Priority? priority;
  final CompletionFilter completion;

  const TaskQuery({
    this.text = '',
    this.priority,
    this.completion = CompletionFilter.all,
  });

  bool get isActive =>
      text.isNotEmpty || priority != null || completion != CompletionFilter.all;

  TaskQuery copyWith({
    String? text,
    Priority? priority,
    bool clearPriority = false,
    CompletionFilter? completion,
  }) {
    return TaskQuery(
      text: text ?? this.text,
      priority: clearPriority ? null : (priority ?? this.priority),
      completion: completion ?? this.completion,
    );
  }

  @override
  List<Object?> get props => [text, priority, completion];
}
