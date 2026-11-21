import '../../features/events/domain/event.dart';
import '../../features/tasks/domain/task.dart';

enum ScheduledItemType { task, event }

/// A task or an event reduced to what scheduling needs: an id, a title and a
/// time range.
class ScheduledItem {
  const ScheduledItem({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.type,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final ScheduledItemType type;

  Duration get duration => end.difference(start);

  /// Returns null if the task has no scheduled time.
  static ScheduledItem? fromTask(Task task) {
    if (task.startTime == null || task.endTime == null) return null;
    return ScheduledItem(
      id: task.id,
      title: task.title,
      start: task.startTime!,
      end: task.endTime!,
      type: ScheduledItemType.task,
    );
  }

  static ScheduledItem fromEvent(Event event) {
    return ScheduledItem(
      id: event.id,
      title: event.title,
      start: event.startTime,
      end: event.endTime,
      type: ScheduledItemType.event,
    );
  }
}