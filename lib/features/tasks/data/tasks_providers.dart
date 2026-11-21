import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/category.dart';
import '../domain/subtask.dart';
import '../domain/task.dart';
import 'tasks_repository.dart';

final tasksProvider = FutureProvider<List<Task>>((ref) {
  return ref.watch(tasksRepositoryProvider).fetchTasks();
});

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(tasksRepositoryProvider).fetchCategories();
});

/// Subtasks of one task.
final subtasksProvider =
    FutureProvider.family<List<Subtask>, String>((ref, taskId) {
  return ref.watch(tasksRepositoryProvider).fetchSubtasks(taskId);
});