import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/scheduling/daily_progress.dart';
import '../../core/scheduling/scheduled_item.dart';
import '../../core/scheduling/scheduling_service.dart';
import '../../core/theme/app_theme.dart';
import '../auth/data/auth_repository.dart';
import '../events/data/events_repository.dart';
import '../tasks/data/tasks_providers.dart';


class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning,';
    if (h < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  static String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    final fullName = user?.userMetadata?['full_name'] as String? ?? 'there';
    final firstName = fullName.split(' ').first;

    final tasks = ref.watch(tasksProvider).value ?? [];
    final events = ref.watch(eventsProvider).value ?? [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    bool isToday(DateTime d) =>
        d.year == today.year && d.month == today.month && d.day == today.day;

    final progress = DailyProgress.forDay(tasks, today);
    final todayEvents = events.where((e) => isToday(e.startTime)).toList();
    final overdue = tasks.where((t) => t.isOverdue).length;

    final items = <ScheduledItem>[
      for (final e in events) ScheduledItem.fromEvent(e),
      for (final t in tasks)
        if (ScheduledItem.fromTask(t) != null) ScheduledItem.fromTask(t)!,
    ];
    final free = SchedulingService.totalFree(
      SchedulingService.findFreeSlots(
        dayStart: DateTime(today.year, today.month, today.day, 8),
        dayEnd: DateTime(today.year, today.month, today.day, 22),
        items: items,
      ),
    );

    // Next item today that hasn't started yet.
    final upcoming = items
        .where((i) => isToday(i.start) && i.start.isAfter(now))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final next = upcoming.firstOrNull;

    final timeFormat = DateFormat('h:mm a');

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(_greeting(),
                style: const TextStyle(color: AppColors.textMuted)),
            Text(
              '$firstName!',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text("Today's Progress",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: progress.percentage / 100,
                                strokeWidth: 6,
                                backgroundColor: AppColors.border,
                                color: AppColors.purple,
                              ),
                              Center(
                                child: Text(
                                  '${progress.percentage.round()}%',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _Mini('Completed', progress.completed),
                        _Mini('In Progress', progress.inProgress),
                        _Mini('Pending', progress.pending),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Tasks',
                    value: '${tasks.length}',
                    color: AppColors.purple,
                    icon: Icons.list_alt,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Events',
                    value: '${todayEvents.length}',
                    color: AppColors.blue,
                    icon: Icons.event,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Overdue',
                    value: '$overdue',
                    color: Colors.red,
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Available Time',
                    value: _format(free),
                    color: Colors.teal,
                    icon: Icons.timelapse,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Up Next',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: Icon(
                  next == null
                      ? Icons.check_circle_outline
                      : next.type == ScheduledItemType.event
                          ? Icons.event
                          : Icons.task_alt,
                  color: AppColors.purple,
                ),
                title: Text(next?.title ?? 'Nothing else today'),
                subtitle: next == null
                    ? null
                    : Text(
                        '${timeFormat.format(next.start)} - ${timeFormat.format(next.end)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}