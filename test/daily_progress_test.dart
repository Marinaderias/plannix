import 'package:flutter_test/flutter_test.dart';
import 'package:plannix/core/scheduling/daily_progress.dart';
import 'package:plannix/features/tasks/domain/task.dart';
import 'package:plannix/features/tasks/domain/task_enums.dart';

final day = DateTime(2026, 11, 21);

Task task(String id, TaskStatus status, {DateTime? start}) => Task(
      id: id,
      title: id,
      status: status,
      startTime: start,
      endTime: start?.add(const Duration(hours: 1)),
    );

void main() {
  test('counts statuses for tasks scheduled on the day', () {
    final tasks = [
      task('a', TaskStatus.completed, start: DateTime(2026, 11, 21, 9)),
      task('b', TaskStatus.inProgress, start: DateTime(2026, 11, 21, 11)),
      task('c', TaskStatus.pending, start: DateTime(2026, 11, 21, 14)),
      task('d', TaskStatus.pending, start: DateTime(2026, 11, 21, 16)),
    ];
    final p = DailyProgress.forDay(tasks, day);
    expect(p.total, 4);
    expect(p.completed, 1);
    expect(p.inProgress, 1);
    expect(p.pending, 2);
    expect(p.percentage, 25);
  });

  test('ignores tasks on other days and unscheduled tasks', () {
    final tasks = [
      task('a', TaskStatus.completed, start: DateTime(2026, 11, 22, 9)),
      task('b', TaskStatus.completed),
      task('c', TaskStatus.pending, start: DateTime(2026, 11, 21, 9)),
    ];
    final p = DailyProgress.forDay(tasks, day);
    expect(p.total, 1);
    expect(p.percentage, 0);
  });

  test('percentage is 0 when there are no tasks', () {
    expect(DailyProgress.forDay([], day).percentage, 0);
  });

  test('matches the documentation example: 6 of 10 is 60%', () {
    final tasks = [
      for (var i = 0; i < 10; i++)
        task('t$i', i < 6 ? TaskStatus.completed : TaskStatus.pending,
            start: DateTime(2026, 11, 21, 8, i)),
    ];
    expect(DailyProgress.forDay(tasks, day).percentage, 60);
  });
}