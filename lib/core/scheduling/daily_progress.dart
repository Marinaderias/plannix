import '../../features/tasks/domain/task.dart';
import '../../features/tasks/domain/task_enums.dart';

class DailyProgress {
  const DailyProgress({
    required this.total,
    required this.completed,
    required this.inProgress,
    required this.pending,
  });

  final int total;
  final int completed;
  final int inProgress;
  final int pending;

  /// 0..100. Zero when there are no tasks.
  double get percentage => total == 0 ? 0 : completed / total * 100;

  /// Tasks scheduled on [day] (by start time). Events are not tasks, so they
  /// are never counted here.
  static DailyProgress forDay(List<Task> tasks, DateTime day) {
    final dayTasks = tasks.where((t) {
      final start = t.startTime;
      return start != null &&
          start.year == day.year &&
          start.month == day.month &&
          start.day == day.day;
    }).toList();

    int count(TaskStatus s) => dayTasks.where((t) => t.status == s).length;

    return DailyProgress(
      total: dayTasks.length,
      completed: count(TaskStatus.completed),
      inProgress: count(TaskStatus.inProgress),
      pending: count(TaskStatus.pending),
    );
  }
}