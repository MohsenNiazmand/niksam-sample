import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niksam/app.dart';
import 'package:niksam/features/tasks/domain/entities/priority.dart';
import 'package:niksam/features/tasks/domain/entities/task.dart';
import '../../../../support/fake_task_repository.dart';

void main() {
  testWidgets('App boots with fake repo and shows empty state and app bar', (
    tester,
  ) async {
    final fakeRepo = FakeTaskRepository();

    await tester.pumpWidget(MyApp(repository: fakeRepo));
    await tester.pumpAndSettle();

    expect(find.text('Niksam Tasks'), findsOneWidget);
    expect(find.text('No tasks yet. Tap + to create one.'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('Filter with no match shows Clear filters button', (
    tester,
  ) async {
    final fakeRepo = FakeTaskRepository(
      tasks: [
        Task(
          id: '1',
          title: 'Apple',
          description: '',
          priority: Priority.medium,
          isCompleted: false,
          createdAt: DateTime.now(),
        ),
      ],
    );

    await tester.pumpWidget(MyApp(repository: fakeRepo));
    await tester.pumpAndSettle();

    // Search for non-existent task
    await tester.enterText(find.byType(TextField), 'Banana');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('No tasks match your filter'), findsOneWidget);
    expect(find.text('Clear filters'), findsOneWidget);
  });
}
