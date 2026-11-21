import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/category.dart';
import '../domain/task.dart';
import 'tasks_repository.dart';

final tasksProvider = FutureProvider<List<Task>>((ref) {
  return ref.watch(tasksRepositoryProvider).fetchTasks();
});

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(tasksRepositoryProvider).fetchCategories();
});