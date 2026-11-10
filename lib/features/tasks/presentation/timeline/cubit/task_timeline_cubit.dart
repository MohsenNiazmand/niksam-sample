import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niksam/core/utils/result.dart';
import '../../../domain/repositories/task_repository.dart';
import 'task_timeline_state.dart';

class TaskTimelineCubit extends Cubit<TaskTimelineState> {
  final TaskRepository _repo;
  final String taskId;

  TaskTimelineCubit(this._repo, this.taskId) : super(const TaskTimelineState());

  Future<void> load() async {
    emit(state.copyWith(status: TimelineStatus.loading));

    final result = await _repo.getTimeline(taskId);
    switch (result) {
      case Success(:final data):
        emit(
          state.copyWith(
            status: TimelineStatus.success,
            events: data,
            failure: () => null,
          ),
        );
      case Failed(:final failure):
        emit(
          state.copyWith(
            status: TimelineStatus.failure,
            failure: () => failure,
          ),
        );
    }
  }
}
