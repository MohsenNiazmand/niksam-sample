import 'dart:async';
import 'dart:developer' as developer;
import 'package:niksam/core/error/exceptions.dart';
import 'package:niksam/core/error/failures.dart';
import 'package:niksam/core/utils/result.dart';
import 'package:niksam/features/tasks/domain/entities/task.dart';
import 'package:niksam/features/tasks/domain/entities/task_draft.dart';
import 'package:niksam/features/tasks/domain/entities/task_event.dart';
import 'package:niksam/features/tasks/domain/entities/task_query.dart';
import 'package:niksam/features/tasks/domain/entities/write_outcome.dart';
import 'package:niksam/features/tasks/domain/repositories/task_repository.dart';
import 'package:niksam/features/tasks/data/datasources/task_local_datasource.dart';
import 'package:niksam/features/tasks/data/fault/write_fault_injector.dart';

class TaskRepositoryImpl implements TaskRepository {
  final TaskLocalDataSource dataSource;
  final DateTime Function() _now;
  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  TaskRepositoryImpl({required this.dataSource, DateTime Function()? now})
    : _now = (() => (now ?? DateTime.now)().toUtc());

  @override
  Stream<void> get changes => _changesController.stream;

  void _notifyChanged() {
    if (!_changesController.isClosed) {
      _changesController.add(null);
    }
  }

  @override
  Future<Result<List<Task>>> getTasks(TaskQuery query) async {
    try {
      final tasks = await dataSource.getTasks(query);
      return Success(tasks);
    } catch (e) {
      return _handleReadError(e);
    }
  }

  @override
  Future<Result<List<TaskEvent>>> getTimeline(String taskId) async {
    try {
      final events = await dataSource.getTimeline(taskId);
      return Success(events);
    } catch (e) {
      return _handleReadError(e);
    }
  }

  @override
  Future<Result<Task>> create(String id, TaskDraft draft) async {
    try {
      final task = await dataSource.create(id, draft, _now());
      _notifyChanged();
      return Success(task);
    } catch (e) {
      return _handleWriteError(e);
    }
  }

  @override
  Future<Result<WriteOutcome>> update(String id, TaskDraft draft) async {
    try {
      final outcome = await dataSource.update(id, draft, _now());
      if (outcome is Saved) {
        _notifyChanged();
      }
      return Success(outcome);
    } catch (e) {
      return _handleWriteError(e);
    }
  }

  @override
  Future<Result<WriteOutcome>> setCompleted(String id, bool completed) async {
    try {
      final outcome = await dataSource.setCompleted(id, completed, _now());
      if (outcome is Saved) {
        _notifyChanged();
      }
      return Success(outcome);
    } catch (e) {
      return _handleWriteError(e);
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await dataSource.delete(id);
      _notifyChanged();
      return const Success(null);
    } catch (e) {
      return _handleWriteError(e);
    }
  }

  @override
  Future<void> dispose() async {
    if (!_changesController.isClosed) {
      await _changesController.close();
    }
    await dataSource.database.close();
  }

  Result<T> _handleReadError<T>(Object error) {
    developer.log('Read error', error: error);
    if (error is NotFoundException) {
      return Failed(NotFoundFailure(error.message));
    }
    return Failed(
      StorageFailure("Couldn't load your tasks.", error.toString()),
    );
  }

  Result<T> _handleWriteError<T>(Object error) {
    developer.log('Write error', error: error);
    if (error is NotFoundException) {
      return Failed(NotFoundFailure(error.message));
    }
    final msg = error is InjectedWriteException
        ? 'Simulated write failure (FAIL_WRITES). Nothing was saved.'
        : "Couldn't save the change. Nothing was modified — please retry.";
    return Failed(StorageFailure(msg, error.toString()));
  }
}
