import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niksam/core/error/failures.dart';
import 'package:niksam/core/utils/result.dart';
import 'package:niksam/features/tasks/domain/repositories/task_repository.dart';
import 'package:niksam/features/tasks/presentation/form/view/task_form_page.dart';
import '../../../../support/fake_task_repository.dart';

void main() {
  testWidgets('Form validation rejects empty title and does not call repo', (
    tester,
  ) async {
    final fakeRepo = FakeTaskRepository();

    await tester.pumpWidget(
      RepositoryProvider<TaskRepository>.value(
        value: fakeRepo,
        child: const MaterialApp(home: TaskFormPage()),
      ),
    );

    // Tap Save with empty title
    await tester.tap(find.text('Save Task'));
    await tester.pump();

    expect(find.text('Title is required'), findsOneWidget);
    expect(fakeRepo.storedTasks, isEmpty);
  });

  testWidgets(
    'Form failure shows SnackBar, retry succeeds, changing priority does not duplicate SnackBar',
    (tester) async {
      final fakeRepo = FakeTaskRepository();
      fakeRepo.nextCreateResult = const Failed(
        StorageFailure(
          "Couldn't save the change. Nothing was modified — please retry.",
        ),
      );

      await tester.pumpWidget(
        RepositoryProvider<TaskRepository>.value(
          value: fakeRepo,
          child: const MaterialApp(home: TaskFormPage()),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'Test Task');
      await tester.tap(find.text('Save Task'));
      await tester.pumpAndSettle();

      // Verify SnackBar with Retry is shown
      expect(
        find.text(
          "Couldn't save the change. Nothing was modified — please retry.",
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);

      // Change priority (should not trigger another SnackBar due to listenWhen)
      await tester.tap(find.text('High'));
      await tester.pump();

      // Tap Retry
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(fakeRepo.storedTasks.length, equals(1));
    },
  );
}
