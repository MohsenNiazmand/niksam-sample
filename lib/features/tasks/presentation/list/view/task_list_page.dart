import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niksam/features/tasks/domain/entities/task.dart';
import 'package:niksam/features/tasks/domain/entities/task_query.dart';
import 'package:niksam/features/tasks/domain/repositories/task_repository.dart';
import 'package:niksam/features/tasks/presentation/form/view/task_form_page.dart';
import 'package:niksam/features/tasks/presentation/timeline/view/task_timeline_sheet.dart';
import 'package:niksam/features/tasks/presentation/list/bloc/task_list_bloc.dart';
import 'package:niksam/features/tasks/presentation/list/bloc/task_list_event.dart';
import 'package:niksam/features/tasks/presentation/list/bloc/task_list_state.dart';
import 'package:niksam/features/tasks/presentation/list/view/widgets/filter_bar.dart';
import 'package:niksam/features/tasks/presentation/list/view/widgets/search_field.dart';
import 'package:niksam/features/tasks/presentation/list/view/widgets/task_tile.dart';

class TaskListPage extends StatelessWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) =>
          TaskListBloc(ctx.read<TaskRepository>())
            ..add(const TaskListStarted()),
      child: const _TaskListView(),
    );
  }
}

class _TaskListView extends StatefulWidget {
  const _TaskListView();

  @override
  State<_TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<_TaskListView> {
  final GlobalKey<SearchFieldState> _searchKey = GlobalKey<SearchFieldState>();

  void _confirmDelete(BuildContext context, Task task) {
    showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Task?'),
        content: Text(
          'Are you sure you want to delete "${task.title}" and its entire history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        context.read<TaskListBloc>().add(TaskDeleteRequested(task.id));
      }
    });
  }

  void _openTimeline(BuildContext context, Task task) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskTimelineSheet(task: task),
    );
  }

  void _openForm(BuildContext context, [Task? task]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => TaskFormPage(original: task)),
    );
  }

  void _clearAllFilters(BuildContext context) {
    _searchKey.currentState?.clearText();
    final bloc = context.read<TaskListBloc>();
    bloc.add(const TaskListSearchChanged(''));
    bloc.add(const TaskListPriorityChanged(null));
    bloc.add(const TaskListCompletionChanged(CompletionFilter.all));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TaskListBloc, TaskListState>(
      listenWhen: (prev, curr) =>
          curr.actionFailure != null &&
          prev.actionFailure != curr.actionFailure,
      listener: (context, state) {
        final failure = state.actionFailure;
        if (failure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              action: failure.retryEvent != null
                  ? SnackBarAction(
                      label: 'Retry',
                      onPressed: () {
                        context.read<TaskListBloc>().add(failure.retryEvent!);
                      },
                    )
                  : null,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Niksam Tasks')),
        body: Column(
          children: [
            SearchField(
              key: _searchKey,
              onChanged: (text) {
                context.read<TaskListBloc>().add(TaskListSearchChanged(text));
              },
              onClear: () {
                context.read<TaskListBloc>().add(
                  const TaskListSearchChanged(''),
                );
              },
            ),
            const FilterBar(),
            const SizedBox(height: 4),
            Expanded(
              child: BlocBuilder<TaskListBloc, TaskListState>(
                buildWhen: (prev, curr) =>
                    prev.status != curr.status ||
                    prev.tasks != curr.tasks ||
                    prev.loadFailure != curr.loadFailure ||
                    prev.query.isActive != curr.query.isActive,
                builder: (context, state) {
                  switch (state.status) {
                    case TaskListStatus.loading:
                      return const Center(child: CircularProgressIndicator());
                    case TaskListStatus.failure:
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                state.loadFailure?.message ??
                                    'Failed to load tasks',
                                style: Theme.of(context).textTheme.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  context.read<TaskListBloc>().add(
                                    const TaskListReloadRequested(),
                                  );
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      );
                    case TaskListStatus.success:
                      if (state.tasks.isEmpty) {
                        if (state.query.isActive) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('No tasks match your filter'),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    onPressed: () => _clearAllFilters(context),
                                    child: const Text('Clear filters'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.task_alt,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text('No tasks yet. Tap + to create one.'),
                              ],
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: state.tasks.length,
                        itemBuilder: (context, index) {
                          final task = state.tasks[index];
                          return TaskTile(
                            key: ValueKey(task.id),
                            task: task,
                            onTap: () => _openTimeline(context, task),
                            onToggle: (completed) {
                              context.read<TaskListBloc>().add(
                                TaskCompletionSetRequested(task.id, completed),
                              );
                            },
                            onEdit: () => _openForm(context, task),
                            onDelete: () => _confirmDelete(context, task),
                          );
                        },
                      );
                  }
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openForm(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
