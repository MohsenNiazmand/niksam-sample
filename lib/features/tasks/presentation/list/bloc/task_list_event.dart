import 'package:equatable/equatable.dart';
import 'package:niksam/features/tasks/domain/entities/priority.dart';
import 'package:niksam/features/tasks/domain/entities/task_query.dart';

sealed class TaskListEvent extends Equatable {
  const TaskListEvent();

  @override
  List<Object?> get props => [];
}

class TaskListStarted extends TaskListEvent {
  const TaskListStarted();
}

class TaskListSearchChanged extends TaskListEvent {
  final String text;
  const TaskListSearchChanged(this.text);

  @override
  List<Object?> get props => [text];
}

class TaskListPriorityChanged extends TaskListEvent {
  final Priority? priority;
  const TaskListPriorityChanged(this.priority);

  @override
  List<Object?> get props => [priority];
}

class TaskListCompletionChanged extends TaskListEvent {
  final CompletionFilter filter;
  const TaskListCompletionChanged(this.filter);

  @override
  List<Object?> get props => [filter];
}

class TaskListReloadRequested extends TaskListEvent {
  const TaskListReloadRequested();
}

sealed class TaskMutationRequested extends TaskListEvent {
  const TaskMutationRequested();
}

class TaskCompletionSetRequested extends TaskMutationRequested {
  final String id;
  final bool completed;

  const TaskCompletionSetRequested(this.id, this.completed);

  @override
  List<Object?> get props => [id, completed];
}

class TaskDeleteRequested extends TaskMutationRequested {
  final String id;

  const TaskDeleteRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class TaskActionFailureDismissed extends TaskListEvent {
  const TaskActionFailureDismissed();
}
