import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/task.dart';
import '../domain/task_enums.dart';
import 'tasks_providers.dart';

class TasksFilter {
  const TasksFilter({this.categoryId, this.priority, this.status});

  final String? categoryId;
  final TaskPriority? priority;
  final TaskStatus? status;

  bool get isActive =>
      categoryId != null || priority != null || status != null;

  bool matches(Task task) {
    if (categoryId != null && task.categoryId != categoryId) return false;
    if (priority != null && task.priority != priority) return false;
    if (status != null && task.status != status) return false;
    return true;
  }
}

class TasksFilterNotifier extends Notifier<TasksFilter> {
  @override
  TasksFilter build() => const TasksFilter();

  void setCategory(String? id) => state = TasksFilter(
        categoryId: id,
        priority: state.priority,
        status: state.status,
      );

  void setPriority(TaskPriority? p) => state = TasksFilter(
        categoryId: state.categoryId,
        priority: p,
        status: state.status,
      );

  void setStatus(TaskStatus? s) => state = TasksFilter(
        categoryId: state.categoryId,
        priority: state.priority,
        status: s,
      );

  void clear() => state = const TasksFilter();
}

final tasksFilterProvider =
    NotifierProvider<TasksFilterNotifier, TasksFilter>(
        TasksFilterNotifier.new);

/// Tasks after applying the current filter.
final filteredTasksProvider = Provider<AsyncValue<List<Task>>>((ref) {
  final filter = ref.watch(tasksFilterProvider);
  return ref
      .watch(tasksProvider)
      .whenData((tasks) => tasks.where(filter.matches).toList());
});