import 'package:equatable/equatable.dart';
import 'package:niksam/core/error/failures.dart';
import 'package:niksam/features/tasks/domain/entities/task_event.dart';

enum TimelineStatus { loading, success, failure }

class TaskTimelineState extends Equatable {
  final TimelineStatus status;
  final List<TaskEvent> events;
  final Failure? failure;

  const TaskTimelineState({
    this.status = TimelineStatus.loading,
    this.events = const [],
    this.failure,
  });

  bool get isEmpty => status == TimelineStatus.success && events.isEmpty;

  TaskTimelineState copyWith({
    TimelineStatus? status,
    List<TaskEvent>? events,
    Failure? Function()? failure,
  }) {
    return TaskTimelineState(
      status: status ?? this.status,
      events: events ?? this.events,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [status, events, failure];
}
