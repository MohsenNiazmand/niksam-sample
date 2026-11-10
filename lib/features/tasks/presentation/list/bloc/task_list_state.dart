import 'package:equatable/equatable.dart';
import 'package:niksam/core/error/failures.dart';
import 'package:niksam/features/tasks/domain/entities/task.dart';
import 'package:niksam/features/tasks/domain/entities/task_query.dart';
import 'package:niksam/features/tasks/presentation/list/bloc/task_list_event.dart';

enum TaskListStatus { loading, success, failure }

class ActionFailure extends Equatable {
  final String message;
  final TaskListEvent? retryEvent;
  final int token;

  const ActionFailure({
    required this.message,
    required this.retryEvent,
    required this.token,
  });

  @override
  List<Object?> get props => [message, retryEvent, token];
}

class TaskListState extends Equatable {
  final TaskListStatus status;
  final List<Task> tasks;
  final TaskQuery query;
  final Failure? loadFailure;
  final ActionFailure? actionFailure;

  const TaskListState({
    this.status = TaskListStatus.loading,
    this.tasks = const [],
    this.query = const TaskQuery(),
    this.loadFailure,
    this.actionFailure,
  });

  bool get isEmpty => status == TaskListStatus.success && tasks.isEmpty;

  TaskListState copyWith({
    TaskListStatus? status,
    List<Task>? tasks,
    TaskQuery? query,
    Failure? Function()? loadFailure,
    ActionFailure? Function()? actionFailure,
  }) {
    return TaskListState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      query: query ?? this.query,
      loadFailure: loadFailure != null ? loadFailure() : this.loadFailure,
      actionFailure: actionFailure != null
          ? actionFailure()
          : this.actionFailure,
    );
  }

  @override
  List<Object?> get props => [status, tasks, query, loadFailure, actionFailure];
}
