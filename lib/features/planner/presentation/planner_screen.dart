import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/scheduling/daily_progress.dart';
import '../../../core/scheduling/scheduled_item.dart';
import '../../../core/theme/app_theme.dart';
import '../../events/data/events_repository.dart';
import '../../events/domain/event.dart';
import '../../events/presentation/event_form_screen.dart';
import '../../tasks/data/tasks_providers.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_details_screen.dart';
import 'available_time_screen.dart';

const double _hourHeight = 64;
const int _firstHour = 8;
const int _lastHour = 22;

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  DateTime _day = DateTime.now();

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _shift(int days) =>
      setState(() => _day = _day.add(Duration(days: days)));

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _day = picked);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider).value ?? [];
    final events = ref.watch(eventsProvider).value ?? [];
    final progress = DailyProgress.forDay(tasks, _day);

    final entries = <_PlannerEntry>[
      for (final e in events)
        if (_sameDay(e.startTime, _day)) _PlannerEntry.event(e),
      for (final t in tasks)
        if (ScheduledItem.fromTask(t) != null && _sameDay(t.startTime!, _day))
          _PlannerEntry.task(t),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: _pickDay,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EventFormScreen(initialDate: _day)),
        ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shift(-1),
              ),
              Text(
                DateFormat('EEE, MMM d, y').format(_day),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shift(1),
              ),
                        IconButton(
            icon: const Icon(Icons.timelapse),
            tooltip: 'Available time',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AvailableTimeScreen(initialDay: _day),
              ),
            ),
          ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatBox('Total', progress.total, AppColors.purple),
                _StatBox('Completed', progress.completed, Colors.green),
                _StatBox('In Progress', progress.inProgress, AppColors.blue),
                _StatBox('Pending', progress.pending, Colors.orange),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress.percentage / 100,
                      minHeight: 8,
                      backgroundColor: AppColors.border,
                      color: AppColors.purple,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${progress.percentage.round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Expanded(
            child: _Timeline(
              day: _day,
              entries: entries,
              onTap: (entry) {
                if (entry.event != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EventFormScreen(event: entry.event),
                    ),
                  );
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TaskDetailsScreen(taskId: entry.task!.id),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannerEntry {
  _PlannerEntry.event(Event e)
    : event = e,
      task = null,
      title = e.title,
      start = e.startTime,
      end = e.endTime,
      color = colorFromHex(e.color);

  _PlannerEntry.task(Task t)
    : task = t,
      event = null,
      title = t.title,
      start = t.startTime!,
      end = t.endTime!,
      color = t.priority.color;

  final Event? event;
  final Task? task;
  final String title;
  final DateTime start;
  final DateTime end;
  final Color color;
}

class _StatBox extends StatelessWidget {
  const _StatBox(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 2),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.day,
    required this.entries,
    required this.onTap,
  });

  final DateTime day;
  final List<_PlannerEntry> entries;
  final ValueChanged<_PlannerEntry> onTap;

  double _offset(DateTime t) =>
      ((t.hour + t.minute / 60) - _firstHour) * _hourHeight;

  @override
  Widget build(BuildContext context) {
    final totalHeight = (_lastHour - _firstHour + 1) * _hourHeight;
    final hourFormat = DateFormat('h a');
    final timeFormat = DateFormat('h:mm a');

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 88),
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          children: [
            for (var h = _firstHour; h <= _lastHour; h++)
              Positioned(
                top: (h - _firstHour) * _hourHeight,
                left: 0,
                right: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 64,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          hourFormat.format(DateTime(2000, 1, 1, h)),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(height: 1)),
                  ],
                ),
              ),
            for (final e in entries)
              Positioned(
                top: _offset(e.start).clamp(0, totalHeight - 24),
                left: 72,
                right: 16,
                height: (e.end.difference(e.start).inMinutes / 60 * _hourHeight)
                    .clamp(28, totalHeight),
                child: GestureDetector(
                  onTap: () => onTap(e),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: e.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border(
                        left: BorderSide(color: e.color, width: 4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${timeFormat.format(e.start)} - ${timeFormat.format(e.end)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
