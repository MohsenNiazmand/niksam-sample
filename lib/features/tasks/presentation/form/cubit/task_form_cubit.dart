import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niksam/core/utils/result.dart';
import 'package:uuid/uuid.dart';
import 'package:niksam/features/tasks/domain/entities/priority.dart';
import 'package:niksam/features/tasks/domain/entities/task.dart';
import 'package:niksam/features/tasks/domain/entities/task_draft.dart';
import 'package:niksam/features/tasks/domain/entities/write_outcome.dart';
import 'package:niksam/features/tasks/domain/logic/task_validator.dart';
import 'package:niksam/features/tasks/domain/repositories/task_repository.dart';
import 'package:niksam/features/tasks/presentation/form/cubit/task_form_state.dart';

class TaskFormCubit extends Cubit<TaskFormState> {
  final TaskRepository _repo;
  int _token = 0;

  TaskFormCubit(this._repo, {Task? original, Uuid? uuid})
    : super(
        TaskFormState(
          mode: original != null ? FormMode.edit : FormMode.create,
          taskId: original?.id ?? (uuid ?? const Uuid()).v4(),
          priority: original?.priority ?? Priority.medium,
          original: original,
        ),
      );

  void priorityChanged(Priority priority) {
    emit(
      state.copyWith(
        priority: priority,
        status: state.status == FormStatus.failure ? FormStatus.editing : null,
      ),
    );
  }

  void titleEdited() {
    if (state.titleError != null || state.status == FormStatus.failure) {
      emit(
        state.copyWith(
          titleError: () => null,
          status: state.status == FormStatus.failure
              ? FormStatus.editing
              : null,
        ),
      );
    }
  }

  Future<void> submit(String title, String description) async {
    if (state.status == FormStatus.submitting) return;

    final titleError = TaskValidator.validateTitle(title);
    if (titleError != null) {
      emit(
        state.copyWith(
          titleError: () => titleError,
          status: FormStatus.editing,
        ),
      );
      return;
    }

    emit(state.copyWith(status: FormStatus.submitting));

    final draft = TaskDraft(
      title: title,
      description: description,
      priority: state.priority,
    );

    if (state.mode == FormMode.create) {
      final Result<Task> result = await _repo.create(state.taskId, draft);
      if (isClosed) return;

      switch (result) {
        case Success():
          emit(state.copyWith(status: FormStatus.success, failure: () => null));
        case Failed(:final failure):
          _token++;
          emit(
            state.copyWith(
              status: FormStatus.failure,
              failure: () => failure,
              token: _token,
            ),
          );
      }
    } else {
      final Result<WriteOutcome> result = await _repo.update(
        state.taskId,
        draft,
      );
      if (isClosed) return;

      switch (result) {
        case Success():
          emit(state.copyWith(status: FormStatus.success, failure: () => null));
        case Failed(:final failure):
          _token++;
          emit(
            state.copyWith(
              status: FormStatus.failure,
              failure: () => failure,
              token: _token,
            ),
          );
      }
    }
  }
}
