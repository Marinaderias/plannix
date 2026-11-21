import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/task.dart';
import '../domain/task_enums.dart';
import 'tasks_providers.dart';

class TasksFilter {
  const TasksFilter({
    this.categoryId,
    this.priority,
    this.status,
    this.query = '',
  });

  final String? categoryId;
  final TaskPriority? priority;
  final TaskStatus? status;
  final String query;

  /// Active "advanced" filters (category/priority), not counting tabs/search.
  bool get hasAdvancedFilters => categoryId != null || priority != null;

  bool get isActive =>
      categoryId != null ||
      priority != null ||
      status != null ||
      query.isNotEmpty;

  bool matches(Task task) {
    if (categoryId != null && task.categoryId != categoryId) return false;
    if (priority != null && task.priority != priority) return false;
    if (status != null && task.status != status) return false;
    if (query.isNotEmpty &&
        !task.title.toLowerCase().contains(query.toLowerCase())) {
      return false;
    }
    return true;
  }

  TasksFilter copyWith({
    String? categoryId,
    bool clearCategory = false,
    TaskPriority? priority,
    bool clearPriority = false,
    TaskStatus? status,
    bool clearStatus = false,
    String? query,
  }) {
    return TasksFilter(
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      priority: clearPriority ? null : (priority ?? this.priority),
      status: clearStatus ? null : (status ?? this.status),
      query: query ?? this.query,
    );
  }
}

class TasksFilterNotifier extends Notifier<TasksFilter> {
  @override
  TasksFilter build() => const TasksFilter();

  void setCategory(String? id) =>
      state = state.copyWith(categoryId: id, clearCategory: id == null);

  void setPriority(TaskPriority? p) =>
      state = state.copyWith(priority: p, clearPriority: p == null);

  void setStatus(TaskStatus? s) =>
      state = state.copyWith(status: s, clearStatus: s == null);

  void setQuery(String q) => state = state.copyWith(query: q);

  void clearAdvanced() => state =
      state.copyWith(clearCategory: true, clearPriority: true);

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