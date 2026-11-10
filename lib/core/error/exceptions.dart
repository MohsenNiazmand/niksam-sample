class NotFoundException implements Exception {
  final String message;
  const NotFoundException([this.message = 'Not found']);

  @override
  String toString() => 'NotFoundException: $message';
}
