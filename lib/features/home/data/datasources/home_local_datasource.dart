import '../models/welcome_message_model.dart';

abstract class HomeLocalDataSource {
  Future<WelcomeMessageModel> getWelcomeMessage();
}

class HomeLocalDataSourceImpl implements HomeLocalDataSource {
  @override
  Future<WelcomeMessageModel> getWelcomeMessage() async {
    return const WelcomeMessageModel(
      title: 'Welcome to Niksam',
      subtitle: 'Clean Architecture Flutter project ready for development.',
    );
  }
}
