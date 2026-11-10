import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/entities/task_event.dart';
import '../../../domain/repositories/task_repository.dart';
import '../cubit/task_timeline_cubit.dart';
import '../cubit/task_timeline_state.dart';

class TaskTimelineSheet extends StatelessWidget {
  final Task task;

  const TaskTimelineSheet({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) =>
          TaskTimelineCubit(ctx.read<TaskRepository>(), task.id)..load(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Activity Timeline',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                task.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Divider(height: 24),
              Flexible(
                child: BlocBuilder<TaskTimelineCubit, TaskTimelineState>(
                  builder: (context, state) {
                    switch (state.status) {
                      case TimelineStatus.loading:
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      case TimelineStatus.failure:
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  state.failure?.message ??
                                      'Failed to load timeline',
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () =>
                                      context.read<TaskTimelineCubit>().load(),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        );
                      case TimelineStatus.success:
                        if (state.events.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text('No activity recorded yet.'),
                            ),
                          );
                        }
                        final localizations = MaterialLocalizations.of(context);
                        return ListView.separated(
                          shrinkWrap: true,
                          itemCount: state.events.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final event = state.events[index];
                            final localDateTime = event.at.toLocal();
                            final dateStr = localizations.formatMediumDate(
                              localDateTime,
                            );
                            final timeStr = localizations.formatTimeOfDay(
                              TimeOfDay.fromDateTime(localDateTime),
                            );

                            final (
                              IconData icon,
                              Color color,
                              String description,
                            ) = switch (event.kind) {
                              TaskCreated() => (
                                Icons.add_circle_outline,
                                Colors.blue,
                                'Task created',
                              ),
                              TaskPriorityChanged(:final from, :final to) => (
                                Icons.flag_outlined,
                                Colors.orange,
                                'Priority: ${from.label} → ${to.label}',
                              ),
                              TaskCompleted() => (
                                Icons.check_circle_outline,
                                Colors.green,
                                'Marked as completed',
                              ),
                              TaskReopened() => (
                                Icons.replay,
                                Colors.purple,
                                'Reopened',
                              ),
                            };

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withAlpha(35),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              title: Text(description),
                              subtitle: Text('$dateStr at $timeStr'),
                            );
                          },
                        );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
