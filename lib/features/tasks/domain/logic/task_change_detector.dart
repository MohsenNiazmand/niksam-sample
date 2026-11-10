import '../entities/task.dart';
import '../entities/task_draft.dart';
import '../entities/task_event.dart';

abstract final class TaskChangeDetector {
  static bool hasChanges(Task stored, TaskDraft next) {
    final normalized = next.normalized();
    final storedTitle = stored.title.trim();
    final storedDesc = stored.description.trim();
    return storedTitle != normalized.title ||
        storedDesc != normalized.description ||
        stored.priority != normalized.priority;
  }

  static List<TaskEventKind> eventsForUpdate(Task stored, TaskDraft next) {
    final normalized = next.normalized();
    if (stored.priority != normalized.priority) {
      return [
        TaskPriorityChanged(from: stored.priority, to: normalized.priority),
      ];
    }
    return const [];
  }

  static TaskEventKind? eventForCompletion(Task stored, bool target) {
    if (stored.isCompleted == target) {
      return null;
    }
    return target ? const TaskCompleted() : const TaskReopened();
  }
}
