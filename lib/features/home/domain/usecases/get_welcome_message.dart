import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/welcome_message.dart';
import '../repositories/home_repository.dart';

class GetWelcomeMessage implements UseCase<WelcomeMessage, NoParams> {
  final HomeRepository repository;

  const GetWelcomeMessage(this.repository);

  @override
  Future<Result<WelcomeMessage>> call(NoParams params) {
    return repository.getWelcomeMessage();
  }
}
