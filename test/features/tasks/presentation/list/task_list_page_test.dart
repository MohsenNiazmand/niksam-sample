import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niksam/app.dart';
import '../../../../support/fake_task_repository.dart';

void main() {
  testWidgets('App boots with fake repo and shows empty state and app bar', (tester) async {
    final fakeRepo = FakeTaskRepository();

    await tester.pumpWidget(MyApp(repository: fakeRepo));
    await tester.pumpAndSettle();

    expect(find.text('Niksam Tasks'), findsOneWidget);
    expect(find.text('No tasks yet. Tap + to create one.'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
