import '../../features/tasks/domain/task.dart';
import '../../features/tasks/domain/task_enums.dart';

class RecurrenceService {
  const RecurrenceService._();

  /// Moves [date] forward by one recurrence step.
  /// Monthly keeps the same day, clamped to the end of shorter months.
  static DateTime next(DateTime date, Recurrence recurrence) {
    switch (recurrence) {
      case Recurrence.none:
        return date;
      case Recurrence.daily:
        return DateTime(date.year, date.month, date.day + 1, date.hour,
            date.minute);
      case Recurrence.weekly:
        return DateTime(date.year, date.month, date.day + 7, date.hour,
            date.minute);
      case Recurrence.monthly:
        final firstOfNext = DateTime(date.year, date.month + 1, 1);
        final lastDay =
            DateTime(firstOfNext.year, firstOfNext.month + 1, 0).day;
        final day = date.day > lastDay ? lastDay : date.day;
        return DateTime(
            firstOfNext.year, firstOfNext.month, day, date.hour, date.minute);
    }
  }

  /// The next occurrence of [task] as a new pending task, or null if the
  /// task doesn't repeat.
  static Task? nextOccurrence(Task task) {
    if (task.recurrence == Recurrence.none) return null;

    DateTime? shift(DateTime? d) =>
        d == null ? null : next(d, task.recurrence);

    return Task(
      id: '',
      title: task.title,
      description: task.description,
      categoryId: task.categoryId,
      priority: task.priority,
      status: TaskStatus.pending,
      deadline: shift(task.deadline),
      estimatedDurationMinutes: task.estimatedDurationMinutes,
      startTime: shift(task.startTime),
      endTime: shift(task.endTime),
      recurrence: task.recurrence,
      reminderMinutes: task.reminderMinutes,
    );
  }
}