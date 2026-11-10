import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class StorageFailure extends Failure {
  const StorageFailure([super.message = 'Storage Error']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Not Found Error']);
}
