import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:niksam/features/tasks/domain/entities/priority.dart';
import 'package:niksam/features/tasks/domain/entities/task_query.dart';
import '../../bloc/task_list_bloc.dart';
import '../../bloc/task_list_event.dart';
import '../../bloc/task_list_state.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<TaskListBloc, TaskListState, ({Priority? p, CompletionFilter c})>(
      selector: (state) => (p: state.query.priority, c: state.query.completion),
      builder: (context, filter) {
        final bloc = context.read<TaskListBloc>();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              SegmentedButton<CompletionFilter>(
                segments: const [
                  ButtonSegment(
                    value: CompletionFilter.all,
                    label: Text('All'),
                  ),
                  ButtonSegment(
                    value: CompletionFilter.open,
                    label: Text('Open'),
                  ),
                  ButtonSegment(
                    value: CompletionFilter.completed,
                    label: Text('Done'),
                  ),
                ],
                selected: {filter.c},
                onSelectionChanged: (selected) {
                  bloc.add(TaskListCompletionChanged(selected.first));
                },
                showSelectedIcon: false,
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 6,
                children: [
                  FilterChip(
                    label: const Text('All Priorities'),
                    selected: filter.p == null,
                    onSelected: (_) => bloc.add(const TaskListPriorityChanged(null)),
                  ),
                  ...Priority.values.map(
                    (Priority priority) => FilterChip(
                      label: Text(priority.label),
                      selected: filter.p == priority,
                      onSelected: (selected) {
                        bloc.add(TaskListPriorityChanged(selected ? priority : null));
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
