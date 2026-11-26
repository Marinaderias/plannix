import 'package:flutter_test/flutter_test.dart';
import 'package:plannix/core/scheduling/recurrence_service.dart';
import 'package:plannix/features/tasks/domain/task.dart';
import 'package:plannix/features/tasks/domain/task_enums.dart';

void main() {
  test('daily adds one day', () {
    expect(RecurrenceService.next(DateTime(2026, 11, 30, 9), Recurrence.daily),
        DateTime(2026, 12, 1, 9));
  });

  test('weekly adds seven days', () {
    expect(RecurrenceService.next(DateTime(2026, 11, 26, 9), Recurrence.weekly),
        DateTime(2026, 12, 3, 9));
  });

  test('monthly keeps the day', () {
    expect(
        RecurrenceService.next(DateTime(2026, 11, 15, 9), Recurrence.monthly),
        DateTime(2026, 12, 15, 9));
  });

  test('monthly clamps to the end of a shorter month', () {
    expect(
        RecurrenceService.next(DateTime(2026, 1, 31, 9), Recurrence.monthly),
        DateTime(2026, 2, 28, 9));
  });

  test('monthly rolls over the year', () {
    expect(
        RecurrenceService.next(DateTime(2026, 12, 10, 9), Recurrence.monthly),
        DateTime(2027, 1, 10, 9));
  });

  test('nextOccurrence is null for non-repeating tasks', () {
    const t = Task(id: 'a', title: 'x');
    expect(RecurrenceService.nextOccurrence(t), isNull);
  });

  test('nextOccurrence shifts times and resets status', () {
    final t = Task(
      id: 'a',
      title: 'Gym',
      status: TaskStatus.completed,
      recurrence: Recurrence.daily,
      startTime: DateTime(2026, 11, 26, 18),
      endTime: DateTime(2026, 11, 26, 19),
      deadline: DateTime(2026, 11, 26, 20),
    );
    final n = RecurrenceService.nextOccurrence(t)!;
    expect(n.status, TaskStatus.pending);
    expect(n.startTime, DateTime(2026, 11, 27, 18));
    expect(n.endTime, DateTime(2026, 11, 27, 19));
    expect(n.deadline, DateTime(2026, 11, 27, 20));
  });
}