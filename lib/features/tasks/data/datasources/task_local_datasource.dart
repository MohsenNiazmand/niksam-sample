import '../../../../core/error/exceptions.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_draft.dart';
import '../../domain/entities/task_event.dart';
import '../../domain/entities/task_query.dart';
import '../../domain/entities/write_outcome.dart';
import '../../domain/logic/task_change_detector.dart';
import '../database/app_database.dart';
import '../fault/write_fault_injector.dart';
import '../models/task_event_model.dart';
import '../models/task_model.dart';

class TaskLocalDataSource {
  final AppDatabase database;
  final WriteFaultInjector faultInjector;

  TaskLocalDataSource({
    required this.database,
    this.faultInjector = const NoFault(),
  });

  static String escapeLike(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  Future<List<Task>> getTasks(TaskQuery query) async {
    final db = await database.database;
    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (query.text.trim().isNotEmpty) {
      final escaped = escapeLike(query.text.trim());
      whereClauses.add("title LIKE ? ESCAPE '\\'");
      whereArgs.add('%$escaped%');
    }

    if (query.priority != null) {
      whereClauses.add('priority = ?');
      whereArgs.add(query.priority!.name);
    }

    switch (query.completion) {
      case CompletionFilter.open:
        whereClauses.add('is_completed = 0');
        break;
      case CompletionFilter.completed:
        whereClauses.add('is_completed = 1');
        break;
      case CompletionFilter.all:
        break;
    }

    final where = whereClauses.isEmpty ? null : whereClauses.join(' AND ');
    final maps = await db.query(
      'tasks',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC, id DESC',
    );

    return maps.map(TaskModel.fromMap).toList();
  }

  Future<List<TaskEvent>> getTimeline(String taskId) async {
    final db = await database.database;
    final maps = await db.query(
      'task_events',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'occurred_at ASC, id ASC',
    );
    return maps.map(TaskEventModel.fromMap).toList();
  }

  Future<Task> create(String id, TaskDraft draft, DateTime now) async {
    faultInjector.beginWrite();
    final db = await database.database;
    final normalized = draft.normalized();

    final task = Task(
      id: id,
      title: normalized.title,
      description: normalized.description,
      priority: normalized.priority,
      isCompleted: false,
      createdAt: now,
    );

    await db.transaction((txn) async {
      await txn.insert('tasks', TaskModel.toMap(task));
      faultInjector.checkpoint('after_task_write');

      await txn.insert(
        'task_events',
        TaskEventModel.toMap(
          taskId: id,
          at: now,
          kind: const TaskCreated(),
        ),
      );
      faultInjector.checkpoint('before_commit');
    });

    return task;
  }

  Future<WriteOutcome> update(String id, TaskDraft draft, DateTime now) async {
    faultInjector.beginWrite();
    final db = await database.database;

    return await db.transaction((txn) async {
      final rows = await txn.query('tasks', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) {
        throw NotFoundException('Task not found: $id');
      }

      final stored = TaskModel.fromMap(rows.first);
      if (!TaskChangeDetector.hasChanges(stored, draft)) {
        return const Unchanged();
      }

      final normalized = draft.normalized();
      final updatedTask = stored.copyWith(
        title: normalized.title,
        description: normalized.description,
        priority: normalized.priority,
      );

      await txn.update(
        'tasks',
        TaskModel.toMap(updatedTask),
        where: 'id = ?',
        whereArgs: [id],
      );
      faultInjector.checkpoint('after_task_write');

      final events = TaskChangeDetector.eventsForUpdate(stored, draft);
      for (final eventKind in events) {
        await txn.insert(
          'task_events',
          TaskEventModel.toMap(taskId: id, at: now, kind: eventKind),
        );
      }
      faultInjector.checkpoint('before_commit');

      return Saved(updatedTask);
    });
  }

  Future<WriteOutcome> setCompleted(String id, bool completed, DateTime now) async {
    faultInjector.beginWrite();
    final db = await database.database;

    return await db.transaction((txn) async {
      final rows = await txn.query('tasks', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) {
        throw NotFoundException('Task not found: $id');
      }

      final stored = TaskModel.fromMap(rows.first);
      final eventKind = TaskChangeDetector.eventForCompletion(stored, completed);
      if (eventKind == null) {
        return const Unchanged();
      }

      final updatedTask = stored.copyWith(isCompleted: completed);
      await txn.update(
        'tasks',
        {'is_completed': completed ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      faultInjector.checkpoint('after_task_write');

      await txn.insert(
        'task_events',
        TaskEventModel.toMap(taskId: id, at: now, kind: eventKind),
      );
      faultInjector.checkpoint('before_commit');

      return Saved(updatedTask);
    });
  }

  Future<void> delete(String id, DateTime now) async {
    faultInjector.beginWrite();
    final db = await database.database;

    await db.transaction((txn) async {
      final rows = await txn.query('tasks', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) {
        throw NotFoundException('Task not found: $id');
      }

      await txn.delete('tasks', where: 'id = ?', whereArgs: [id]);
      faultInjector.checkpoint('after_task_write');
      faultInjector.checkpoint('before_commit');
    });
  }
}
