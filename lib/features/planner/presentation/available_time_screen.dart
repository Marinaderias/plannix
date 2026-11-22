import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/scheduling/scheduled_item.dart';
import '../../../core/scheduling/scheduling_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../events/data/events_repository.dart';
import '../../tasks/data/tasks_providers.dart';
import '../../tasks/data/tasks_repository.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/domain/task_enums.dart';

const int _dayStartHour = 8;
const int _dayEndHour = 22;

class AvailableTimeScreen extends ConsumerStatefulWidget {
  const AvailableTimeScreen({super.key, this.initialDay});

  final DateTime? initialDay;

  @override
  ConsumerState<AvailableTimeScreen> createState() =>
      _AvailableTimeScreenState();
}

class _AvailableTimeScreenState extends ConsumerState<AvailableTimeScreen> {
  late DateTime _day = widget.initialDay ?? DateTime.now();

  void _shift(int days) =>
      setState(() => _day = _day.add(Duration(days: days)));

  static String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// Lets the user pick an unscheduled task and puts it at the start of [slot].
  Future<void> _scheduleInSlot(TimeSlot slot) async {
    final tasks = ref.read(tasksProvider).value ?? [];
    final candidates = tasks
        .where((t) => !t.isScheduled && t.status != TaskStatus.completed)
        .toList();

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unscheduled tasks to place here')),
      );
      return;
    }

    final task = await showModalBottomSheet<Task>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Choose a task',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            for (final t in candidates)
              ListTile(
                leading: Icon(Icons.circle, size: 12, color: t.priority.color),
                title: Text(t.title),
                subtitle: Text(
                  t.estimatedDurationMinutes == null
                      ? '1h (default)'
                      : _format(Duration(minutes: t.estimatedDurationMinutes!)),
                ),
                onTap: () => Navigator.pop(ctx, t),
              ),
          ],
        ),
      ),
    );
    if (task == null || !mounted) return;

    final duration = Duration(minutes: task.estimatedDurationMinutes ?? 60);
    if (duration > slot.duration) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '"${task.title}" needs ${_format(duration)} but this slot is ${_format(slot.duration)}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await ref.read(tasksRepositoryProvider).scheduleTask(
            task.id,
            start: slot.start,
            end: slot.start.add(duration),
          );
      ref.invalidate(tasksProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not schedule the task'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider).value ?? [];
    final events = ref.watch(eventsProvider).value ?? [];

    final items = <ScheduledItem>[
      for (final e in events) ScheduledItem.fromEvent(e),
      for (final t in tasks)
        if (ScheduledItem.fromTask(t) != null) ScheduledItem.fromTask(t)!,
    ];

    final slots = SchedulingService.findFreeSlots(
      dayStart: DateTime(_day.year, _day.month, _day.day, _dayStartHour),
      dayEnd: DateTime(_day.year, _day.month, _day.day, _dayEndHour),
      items: items,
    );
    final total = SchedulingService.totalFree(slots);
    final timeFormat = DateFormat('h:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('Available Time')),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
            ],
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Available Time',
                      style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  Text(
                    _format(total),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.purple,
                    ),
                  ),
                  Text(
                    '${timeFormat.format(DateTime(2000, 1, 1, _dayStartHour))} - ${timeFormat.format(DateTime(2000, 1, 1, _dayEndHour))}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Available Slots',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (slots.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No free time on this day',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            for (final s in slots)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                      '${timeFormat.format(s.start)} - ${timeFormat.format(s.end)}'),
                  subtitle: Text(_format(s.duration)),
                  trailing: const Icon(Icons.add_circle_outline,
                      color: AppColors.purple),
                  onTap: () => _scheduleInSlot(s),
                ),
              ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: schedule important tasks during your most productive hours.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}