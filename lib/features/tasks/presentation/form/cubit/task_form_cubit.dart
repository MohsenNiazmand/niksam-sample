import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niksam/core/utils/result.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/priority.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/task_draft.dart';
import '../../../domain/logic/task_validator.dart';
import '../../../domain/repositories/task_repository.dart';
import 'task_form_state.dart';

class TaskFormCubit extends Cubit<TaskFormState> {
  final TaskRepository _repo;
  int _token = 0;

  TaskFormCubit(
    this._repo, {
    Task? original,
    Uuid? uuid,
  }) : super(
          TaskFormState(
            mode: original != null ? FormMode.edit : FormMode.create,
            taskId: original?.id ?? (uuid ?? const Uuid()).v4(),
            priority: original?.priority ?? Priority.medium,
            original: original,
          ),
        );

  void priorityChanged(Priority priority) {
    emit(state.copyWith(priority: priority));
  }

  void titleEdited() {
    if (state.titleError != null) {
      emit(state.copyWith(titleError: () => null));
    }
  }

  Future<void> submit(String title, String description) async {
    if (state.status == FormStatus.submitting) return;

    final titleError = TaskValidator.validateTitle(title);
    if (titleError != null) {
      emit(state.copyWith(
        titleError: () => titleError,
        status: FormStatus.editing,
      ));
      return;
    }

    emit(state.copyWith(status: FormStatus.submitting));

    final draft = TaskDraft(
      title: title,
      description: description,
      priority: state.priority,
    );

    final Result<dynamic> result;
    if (state.mode == FormMode.create) {
      result = await _repo.create(state.taskId, draft);
    } else {
      result = await _repo.update(state.taskId, draft);
    }

    switch (result) {
      case Success():
        emit(state.copyWith(
          status: FormStatus.success,
          failure: () => null,
        ));
      case Failed(:final failure):
        _token++;
        emit(state.copyWith(
          status: FormStatus.failure,
          failure: () => failure,
          token: _token,
        ));
    }
  }
}
