import 'dart:async';
import 'package:niksam/core/error/failures.dart';
import 'package:niksam/core/utils/result.dart';
import 'package:niksam/features/tasks/domain/entities/task.dart';
import 'package:niksam/features/tasks/domain/entities/task_draft.dart';
import 'package:niksam/features/tasks/domain/entities/task_event.dart';
import 'package:niksam/features/tasks/domain/entities/task_query.dart';
import 'package:niksam/features/tasks/domain/entities/write_outcome.dart';
import 'package:niksam/features/tasks/domain/repositories/task_repository.dart';

class FakeTaskRepository implements TaskRepository {
  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  List<Task> storedTasks;
  List<TaskEvent> storedEvents;

  // Hooks for custom control in tests
  Completer<Result<List<Task>>>? nextGetTasksCompleter;
  List<TaskQuery> getTasksHistory = [];
  int activeMutations = 0;
  int maxConcurrentMutations = 0;
  Result<Task>? nextCreateResult;
  Result<WriteOutcome>? nextUpdateResult;
  Result<WriteOutcome>? nextSetCompletedResult;
  Result<void>? nextDeleteResult;
  Result<List<Task>>? nextGetTasksResult;

  FakeTaskRepository({List<Task>? tasks, List<TaskEvent>? events})
    : storedTasks = tasks ?? [],
      storedEvents = events ?? [];

  void emitChange() {
    _changesController.add(null);
  }

  @override
  Stream<void> get changes => _changesController.stream;

  @override
  Future<Result<List<Task>>> getTasks(TaskQuery query) async {
    getTasksHistory.add(query);
    if (nextGetTasksCompleter != null) {
      final completer = nextGetTasksCompleter!;
      nextGetTasksCompleter = null;
      return await completer.future;
    }
    if (nextGetTasksResult != null) {
      final res = nextGetTasksResult!;
      nextGetTasksResult = null;
      return res;
    }

    var list = List<Task>.from(storedTasks);
    if (query.text.isNotEmpty) {
      list = list.where((t) => t.title.contains(query.text)).toList();
    }
    if (query.priority != null) {
      list = list.where((t) => t.priority == query.priority).toList();
    }
    if (query.completion == CompletionFilter.open) {
      list = list.where((t) => !t.isCompleted).toList();
    } else if (query.completion == CompletionFilter.completed) {
      list = list.where((t) => t.isCompleted).toList();
    }
    return Success(list);
  }

  @override
  Future<Result<List<TaskEvent>>> getTimeline(String taskId) async {
    final list = storedEvents.where((e) => e.taskId == taskId).toList();
    return Success(list);
  }

  @override
  Future<Result<Task>> create(String id, TaskDraft draft) async {
    if (nextCreateResult != null) {
      final res = nextCreateResult!;
      nextCreateResult = null;
      return res;
    }

    final task = Task(
      id: id,
      title: draft.title,
      description: draft.description,
      priority: draft.priority,
      isCompleted: false,
      createdAt: DateTime.now().toUtc(),
    );
    storedTasks.add(task);
    _changesController.add(null);
    return Success(task);
  }

  @override
  Future<Result<WriteOutcome>> update(String id, TaskDraft draft) async {
    if (nextUpdateResult != null) {
      final res = nextUpdateResult!;
      nextUpdateResult = null;
      return res;
    }

    final index = storedTasks.indexWhere((t) => t.id == id);
    if (index == -1) {
      return const Failed(NotFoundFailure());
    }
    final updated = storedTasks[index].copyWith(
      title: draft.title,
      description: draft.description,
      priority: draft.priority,
    );
    storedTasks[index] = updated;
    _changesController.add(null);
    return Success(Saved(updated));
  }

  @override
  Future<Result<WriteOutcome>> setCompleted(String id, bool completed) async {
    activeMutations++;
    if (activeMutations > maxConcurrentMutations) {
      maxConcurrentMutations = activeMutations;
    }

    try {
      if (nextSetCompletedResult != null) {
        final res = nextSetCompletedResult!;
        nextSetCompletedResult = null;
        return res;
      }

      final index = storedTasks.indexWhere((t) => t.id == id);
      if (index == -1) {
        return const Failed(NotFoundFailure());
      }
      final updated = storedTasks[index].copyWith(isCompleted: completed);
      storedTasks[index] = updated;
      _changesController.add(null);
      return Success(Saved(updated));
    } finally {
      activeMutations--;
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    activeMutations++;
    if (activeMutations > maxConcurrentMutations) {
      maxConcurrentMutations = activeMutations;
    }

    try {
      if (nextDeleteResult != null) {
        final res = nextDeleteResult!;
        nextDeleteResult = null;
        return res;
      }

      final index = storedTasks.indexWhere((t) => t.id == id);
      if (index == -1) {
        return const Failed(NotFoundFailure());
      }
      storedTasks.removeAt(index);
      _changesController.add(null);
      return const Success(null);
    } finally {
      activeMutations--;
    }
  }

  @override
  Future<void> dispose() async {
    await _changesController.close();
  }
}
