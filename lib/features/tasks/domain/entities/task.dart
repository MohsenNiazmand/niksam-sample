import 'package:equatable/equatable.dart';
import 'priority.dart';

class Task extends Equatable {
  final String id;
  final String title;
  final String description;
  final Priority priority;
  final bool isCompleted;
  final DateTime createdAt;

  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.isCompleted,
    required this.createdAt,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    Priority? priority,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        priority,
        isCompleted,
        createdAt,
      ];
}
