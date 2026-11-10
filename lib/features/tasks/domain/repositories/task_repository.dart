import 'package:niksam/core/utils/result.dart';
import 'package:niksam/features/tasks/domain/entities/task.dart';
import 'package:niksam/features/tasks/domain/entities/task_draft.dart';
import 'package:niksam/features/tasks/domain/entities/task_event.dart';
import 'package:niksam/features/tasks/domain/entities/task_query.dart';
import 'package:niksam/features/tasks/domain/entities/write_outcome.dart';

abstract interface class TaskRepository {
  Stream<void> get changes;
  Future<Result<List<Task>>> getTasks(TaskQuery query);
  Future<Result<List<TaskEvent>>> getTimeline(String taskId);
  Future<Result<Task>> create(String id, TaskDraft draft);
  Future<Result<WriteOutcome>> update(String id, TaskDraft draft);
  Future<Result<WriteOutcome>> setCompleted(String id, bool completed);
  Future<Result<void>> delete(String id);
  Future<void> dispose();
}
