import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/welcome_message.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_local_datasource.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeLocalDataSource localDataSource;

  const HomeRepositoryImpl({required this.localDataSource});

  @override
  Future<Result<WelcomeMessage>> getWelcomeMessage() async {
    try {
      final message = await localDataSource.getWelcomeMessage();
      return Success(message);
    } catch (e) {
      return const Error(CacheFailure('Failed to load welcome message'));
    }
  }
}
