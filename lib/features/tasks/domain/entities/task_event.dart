import 'package:equatable/equatable.dart';
import 'priority.dart';

sealed class TaskEventKind extends Equatable {
  const TaskEventKind();
}

class TaskCreated extends TaskEventKind {
  const TaskCreated();

  @override
  List<Object?> get props => [];
}

class TaskPriorityChanged extends TaskEventKind {
  final Priority from;
  final Priority to;

  const TaskPriorityChanged({required this.from, required this.to});

  @override
  List<Object?> get props => [from, to];
}

class TaskCompleted extends TaskEventKind {
  const TaskCompleted();

  @override
  List<Object?> get props => [];
}

class TaskReopened extends TaskEventKind {
  const TaskReopened();

  @override
  List<Object?> get props => [];
}

class TaskEvent extends Equatable {
  final int id;
  final String taskId;
  final DateTime at;
  final TaskEventKind kind;

  const TaskEvent({
    required this.id,
    required this.taskId,
    required this.at,
    required this.kind,
  });

  @override
  List<Object?> get props => [id, taskId, at, kind];
}
