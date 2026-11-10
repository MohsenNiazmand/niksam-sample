abstract final class AppConfig {
  static const failWrites = bool.fromEnvironment('FAIL_WRITES');
  static const failFirstWrites = int.fromEnvironment('FAIL_FIRST_WRITES');
}
