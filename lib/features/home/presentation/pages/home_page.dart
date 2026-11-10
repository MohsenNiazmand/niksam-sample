import 'package:flutter/material.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../../data/datasources/home_local_datasource.dart';
import '../../data/repositories/home_repository_impl.dart';
import '../../domain/entities/welcome_message.dart';
import '../../domain/usecases/get_welcome_message.dart';
import '../widgets/welcome_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final GetWelcomeMessage _getWelcomeMessage;
  WelcomeMessage? _message;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // In production, use dependency injection (e.g. get_it, provider, or riverpod)
    final localDataSource = HomeLocalDataSourceImpl();
    final repository = HomeRepositoryImpl(localDataSource: localDataSource);
    _getWelcomeMessage = GetWelcomeMessage(repository);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _getWelcomeMessage(const NoParams());

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      switch (result) {
        case Success<WelcomeMessage>(:final data):
          _message = data;
        case Error<WelcomeMessage>(:final failure):
          _errorMessage = failure.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Niksam'),
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _errorMessage != null
                ? Text(_errorMessage!)
                : _message != null
                    ? WelcomeCard(message: _message!)
                    : const SizedBox.shrink(),
      ),
    );
  }
}
