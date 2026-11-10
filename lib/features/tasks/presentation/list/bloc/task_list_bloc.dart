import 'dart:async';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niksam/core/error/failures.dart';
import 'package:niksam/core/utils/result.dart';
import 'package:stream_transform/stream_transform.dart';
import '../../../domain/entities/task_query.dart';
import '../../../domain/repositories/task_repository.dart';
import 'task_list_event.dart';
import 'task_list_state.dart';

EventTransformer<E> _debounceRestartable<E>(Duration duration) {
  return (events, mapper) => restartable<E>()(events.debounce(duration), mapper);
}

class TaskListBloc extends Bloc<TaskListEvent, TaskListState> {
  final TaskRepository _repo;
  StreamSubscription<void>? _changesSubscription;
  int _token = 0;

  TaskListBloc(this._repo) : super(const TaskListState()) {
    _changesSubscription = _repo.changes.listen((_) {
      add(const TaskListReloadRequested());
    });

    on<TaskListStarted>(_onStarted, transformer: restartable());
    on<TaskListReloadRequested>(_onReloadRequested, transformer: restartable());
    on<TaskListSearchChanged>(
      _onSearchChanged,
      transformer: _debounceRestartable(const Duration(milliseconds: 300)),
    );
    on<TaskListPriorityChanged>(_onPriorityChanged, transformer: restartable());
    on<TaskListCompletionChanged>(_onCompletionChanged, transformer: restartable());
    on<TaskMutationRequested>(_onMutationRequested, transformer: sequential());
    on<TaskActionFailureDismissed>(_onActionFailureDismissed);
  }

  Future<void> _onStarted(
    TaskListStarted event,
    Emitter<TaskListState> emit,
  ) async {
    await _applyQuery(state.query, emit);
  }

  Future<void> _onReloadRequested(
    TaskListReloadRequested event,
    Emitter<TaskListState> emit,
  ) async {
    await _applyQuery(state.query, emit);
  }

  Future<void> _onSearchChanged(
    TaskListSearchChanged event,
    Emitter<TaskListState> emit,
  ) async {
    final next = state.query.copyWith(text: event.text);
    await _applyQuery(next, emit);
  }

  Future<void> _onPriorityChanged(
    TaskListPriorityChanged event,
    Emitter<TaskListState> emit,
  ) async {
    final next = state.query.copyWith(
      priority: event.priority,
      clearPriority: event.priority == null,
    );
    await _applyQuery(next, emit);
  }

  Future<void> _onCompletionChanged(
    TaskListCompletionChanged event,
    Emitter<TaskListState> emit,
  ) async {
    final next = state.query.copyWith(completion: event.filter);
    await _applyQuery(next, emit);
  }

  Future<void> _applyQuery(
    TaskQuery next,
    Emitter<TaskListState> emit,
  ) async {
    emit(state.copyWith(
      query: next,
      status: state.tasks.isNotEmpty ? TaskListStatus.success : TaskListStatus.loading,
    ));

    final result = await _repo.getTasks(next);
    if (emit.isDone || state.query != next) return;

    switch (result) {
      case Success(:final data):
        emit(state.copyWith(
          status: TaskListStatus.success,
          tasks: data,
          loadFailure: () => null,
        ));
      case Failed(:final failure):
        emit(state.copyWith(
          status: TaskListStatus.failure,
          loadFailure: () => failure,
        ));
    }
  }

  Future<void> _onMutationRequested(
    TaskMutationRequested event,
    Emitter<TaskListState> emit,
  ) async {
    final Result<dynamic> result;
    switch (event) {
      case TaskCompletionSetRequested(:final id, :final completed):
        result = await _repo.setCompleted(id, completed);
      case TaskDeleteRequested(:final id):
        result = await _repo.delete(id);
    }

    switch (result) {
      case Success():
        emit(state.copyWith(actionFailure: () => null));
      case Failed(:final failure):
        final message = failure is NotFoundFailure ? 'Task no longer exists' : failure.message;
        emit(state.copyWith(
          actionFailure: () => ActionFailure(
            message: message,
            retryEvent: event,
            token: ++_token,
          ),
        ));
        add(const TaskListReloadRequested());
    }
  }

  void _onActionFailureDismissed(
    TaskActionFailureDismissed event,
    Emitter<TaskListState> emit,
  ) {
    emit(state.copyWith(actionFailure: () => null));
  }

  @override
  Future<void> close() async {
    await _changesSubscription?.cancel();
    return super.close();
  }
}
