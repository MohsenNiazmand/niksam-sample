import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'features/tasks/data/database/app_database.dart';
import 'features/tasks/data/datasources/task_local_datasource.dart';
import 'features/tasks/data/fault/write_fault_injector.dart';
import 'features/tasks/data/repositories/task_repository_impl.dart';
import 'features/tasks/domain/repositories/task_repository.dart';
import 'features/tasks/presentation/list/view/task_list_page.dart';

class MyApp extends StatefulWidget {
  final TaskRepository? repository;

  const MyApp({super.key, this.repository});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final TaskRepository _repo;
  bool _ownsRepo = false;

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) {
      _repo = widget.repository!;
      _ownsRepo = false;
    } else {
      final appDb = AppDatabase();
      final dataSource = TaskLocalDataSource(
        database: appDb,
        faultInjector: ConfiguredFault(),
      );
      _repo = TaskRepositoryImpl(dataSource: dataSource);
      _ownsRepo = true;
    }
  }

  @override
  void dispose() {
    if (_ownsRepo) {
      _repo.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<TaskRepository>.value(
      value: _repo,
      child: MaterialApp(
        title: 'Niksam',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const TaskListPage(),
      ),
    );
  }
}
