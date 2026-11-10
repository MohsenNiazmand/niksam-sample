import 'package:equatable/equatable.dart';
import 'package:niksam/core/error/failures.dart';
import 'package:niksam/features/tasks/domain/entities/priority.dart';
import 'package:niksam/features/tasks/domain/entities/task.dart';
import 'package:niksam/features/tasks/domain/logic/task_validator.dart';

enum FormMode { create, edit }

enum FormStatus { editing, submitting, success, failure }

class TaskFormState extends Equatable {
  final FormMode mode;
  final String taskId;
  final Priority priority;
  final TitleError? titleError;
  final FormStatus status;
  final Failure? failure;
  final int token;
  final Task? original;

  const TaskFormState({
    required this.mode,
    required this.taskId,
    required this.priority,
    this.titleError,
    this.status = FormStatus.editing,
    this.failure,
    this.token = 0,
    this.original,
  });

  TaskFormState copyWith({
    FormMode? mode,
    String? taskId,
    Priority? priority,
    TitleError? Function()? titleError,
    FormStatus? status,
    Failure? Function()? failure,
    int? token,
    Task? Function()? original,
  }) {
    return TaskFormState(
      mode: mode ?? this.mode,
      taskId: taskId ?? this.taskId,
      priority: priority ?? this.priority,
      titleError: titleError != null ? titleError() : this.titleError,
      status: status ?? this.status,
      failure: failure != null ? failure() : this.failure,
      token: token ?? this.token,
      original: original != null ? original() : this.original,
    );
  }

  @override
  List<Object?> get props => [
    mode,
    taskId,
    priority,
    titleError,
    status,
    failure,
    token,
    original,
  ];
}
