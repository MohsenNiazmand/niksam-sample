import '../../domain/entities/welcome_message.dart';

class WelcomeMessageModel extends WelcomeMessage {
  const WelcomeMessageModel({
    required super.title,
    required super.subtitle,
  });

  factory WelcomeMessageModel.fromJson(Map<String, dynamic> json) {
    return WelcomeMessageModel(
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
    };
  }
}
