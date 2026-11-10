import 'package:equatable/equatable.dart';
import 'task.dart';

sealed class WriteOutcome extends Equatable {
  const WriteOutcome();
}

class Saved extends WriteOutcome {
  final Task task;

  const Saved(this.task);

  @override
  List<Object?> get props => [task];
}

class Unchanged extends WriteOutcome {
  const Unchanged();

  @override
  List<Object?> get props => [];
}
