import '../../../../core/utils/result.dart';
import '../entities/welcome_message.dart';

abstract class HomeRepository {
  Future<Result<WelcomeMessage>> getWelcomeMessage();
}
