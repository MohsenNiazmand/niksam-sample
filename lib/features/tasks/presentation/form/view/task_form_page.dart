import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/priority.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/logic/task_validator.dart';
import '../../../domain/repositories/task_repository.dart';
import '../cubit/task_form_cubit.dart';
import '../cubit/task_form_state.dart';

class TaskFormPage extends StatelessWidget {
  final Task? original;

  const TaskFormPage({super.key, this.original});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) =>
          TaskFormCubit(ctx.read<TaskRepository>(), original: original),
      child: const _TaskFormView(),
    );
  }
}

class _TaskFormView extends StatefulWidget {
  const _TaskFormView();

  @override
  State<_TaskFormView> createState() => _TaskFormViewState();
}

class _TaskFormViewState extends State<_TaskFormView> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<TaskFormCubit>();
    _titleController = TextEditingController(
      text: cubit.state.original?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: cubit.state.original?.description ?? '',
    );

    _titleController.addListener(_onTitleChanged);
  }

  void _onTitleChanged() {
    context.read<TaskFormCubit>().titleEdited();
  }

  void _submit() {
    context.read<TaskFormCubit>().submit(
      _titleController.text,
      _descriptionController.text,
    );
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TaskFormCubit, TaskFormState>(
      listenWhen: (p, c) => p.status != c.status || p.token != c.token,
      listener: (context, state) {
        if (state.status == FormStatus.success) {
          Navigator.of(context).pop();
        } else if (state.status == FormStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.failure?.message ?? 'Failed to save task'),
              action: SnackBarAction(label: 'Retry', onPressed: _submit),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            context.select<TaskFormCubit, FormMode>((c) => c.state.mode) ==
                    FormMode.create
                ? 'Create Task'
                : 'Edit Task',
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BlocBuilder<TaskFormCubit, TaskFormState>(
                buildWhen: (prev, curr) => prev.titleError != curr.titleError,
                builder: (context, state) {
                  final errorText = switch (state.titleError) {
                    TitleError.empty => 'Title is required',
                    TitleError.tooLong =>
                      'Title must be 120 characters or less',
                    null => null,
                  };

                  return TextField(
                    controller: _titleController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Title *',
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Text('Priority', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              BlocBuilder<TaskFormCubit, TaskFormState>(
                buildWhen: (prev, curr) => prev.priority != curr.priority,
                builder: (context, state) {
                  return SegmentedButton<Priority>(
                    segments: const [
                      ButtonSegment(value: Priority.low, label: Text('Low')),
                      ButtonSegment(
                        value: Priority.medium,
                        label: Text('Medium'),
                      ),
                      ButtonSegment(value: Priority.high, label: Text('High')),
                    ],
                    selected: {state.priority},
                    onSelectionChanged: (selected) {
                      context.read<TaskFormCubit>().priorityChanged(
                        selected.first,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 32),
              BlocBuilder<TaskFormCubit, TaskFormState>(
                buildWhen: (prev, curr) => prev.status != curr.status,
                builder: (context, state) {
                  final isSubmitting = state.status == FormStatus.submitting;
                  return FilledButton(
                    onPressed: isSubmitting ? null : _submit,
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Task'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
