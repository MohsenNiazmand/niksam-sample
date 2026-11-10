import 'dart:async';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_draft.dart';
import '../../domain/entities/task_event.dart';
import '../../domain/entities/task_query.dart';
import '../../domain/entities/write_outcome.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/task_local_datasource.dart';

class TaskRepositoryImpl implements TaskRepository {
  final TaskLocalDataSource dataSource;
  final DateTime Function() _now;
  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  TaskRepositoryImpl({required this.dataSource, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  @override
  Stream<void> get changes => _changesController.stream;

  @override
  Future<Result<List<Task>>> getTasks(TaskQuery query) async {
    try {
      final tasks = await dataSource.getTasks(query);
      return Success(tasks);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Result<List<TaskEvent>>> getTimeline(String taskId) async {
    try {
      final events = await dataSource.getTimeline(taskId);
      return Success(events);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Result<Task>> create(String id, TaskDraft draft) async {
    try {
      final task = await dataSource.create(id, draft, _now());
      _changesController.add(null);
      return Success(task);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Result<WriteOutcome>> update(String id, TaskDraft draft) async {
    try {
      final outcome = await dataSource.update(id, draft, _now());
      if (outcome is Saved) {
        _changesController.add(null);
      }
      return Success(outcome);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Result<WriteOutcome>> setCompleted(String id, bool completed) async {
    try {
      final outcome = await dataSource.setCompleted(id, completed, _now());
      if (outcome is Saved) {
        _changesController.add(null);
      }
      return Success(outcome);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await dataSource.delete(id, _now());
      _changesController.add(null);
      return const Success(null);
    } catch (e) {
      return _handleError(e);
    }
  }

  @override
  Future<void> dispose() async {
    await _changesController.close();
    await dataSource.database.close();
  }

  Result<T> _handleError<T>(Object error) {
    if (error is NotFoundException) {
      return Failed(NotFoundFailure(error.message));
    }
    return Failed(StorageFailure(error.toString()));
  }
}
