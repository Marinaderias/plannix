import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/scheduling/scheduled_item.dart';
import '../../../core/theme/app_theme.dart';
import '../../events/data/events_repository.dart';
import '../../events/domain/event.dart';
import '../../events/presentation/event_form_screen.dart';
import '../../tasks/data/tasks_providers.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_details_screen.dart';

enum CalendarMode { day, week, month }

/// What the calendar shows for a day: a task or an event with a time.
class _Entry {
  _Entry({required this.item, this.task, this.event});

  final ScheduledItem item;
  final Task? task;
  final Event? event;
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarMode _mode = CalendarMode.month;
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  /// All scheduled tasks and events.
  List<_Entry> _allEntries() {
    final tasks = ref.watch(tasksProvider).value ?? [];
    final events = ref.watch(eventsProvider).value ?? [];
    return [
      for (final e in events)
        _Entry(item: ScheduledItem.fromEvent(e), event: e),
      for (final t in tasks)
        if (ScheduledItem.fromTask(t) != null)
          _Entry(item: ScheduledItem.fromTask(t)!, task: t),
    ];
  }

  List<_Entry> _entriesFor(List<_Entry> all, DateTime day) {
    final list = all
        .where((e) => isSameDay(e.item.start, day))
        .toList()
      ..sort((a, b) => a.item.start.compareTo(b.item.start));
    return list;
  }

  void _openEntry(_Entry entry) {
    if (entry.event != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EventFormScreen(event: entry.event),
      ));
    } else if (entry.task != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TaskDetailsScreen(taskId: entry.task!.id),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _allEntries();

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventFormScreen(initialDate: _selected),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _ModeSwitch(
            mode: _mode,
            onChanged: (m) => setState(() => _mode = m),
          ),
          if (_mode != CalendarMode.day)
            TableCalendar<_Entry>(
              firstDay: DateTime(2020),
              lastDay: DateTime(2035),
              focusedDay: _focused,
              selectedDayPredicate: (d) => isSameDay(d, _selected),
              calendarFormat: _mode == CalendarMode.week
                  ? CalendarFormat.week
                  : CalendarFormat.month,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month',
                CalendarFormat.week: 'Week',
              },
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              eventLoader: (day) => _entriesFor(all, day),
              onDaySelected: (selected, focused) => setState(() {
                _selected = selected;
                _focused = focused;
              }),
              onPageChanged: (focused) => _focused = focused,
              calendarStyle: const CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: AppColors.purple,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Color(0x557C3AED),
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: AppColors.blue,
                  shape: BoxShape.circle,
                ),
              ),
            )
          else
            _DayHeader(
              day: _selected,
              onPrev: () => setState(() =>
                  _selected = _selected.subtract(const Duration(days: 1))),
              onNext: () => setState(
                  () => _selected = _selected.add(const Duration(days: 1))),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat('EEEE, MMMM d').format(_selected),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Expanded(
            child: _EntriesList(
              entries: _entriesFor(all, _selected),
              onTap: _openEntry,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final CalendarMode mode;
  final ValueChanged<CalendarMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SegmentedButton<CalendarMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: CalendarMode.day, label: Text('Day')),
          ButtonSegment(value: CalendarMode.week, label: Text('Week')),
          ButtonSegment(value: CalendarMode.month, label: Text('Month')),
        ],
        selected: {mode},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime day;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
        Text(
          DateFormat('MMM d, y').format(day),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
      ],
    );
  }
}

class _EntriesList extends StatelessWidget {
  const _EntriesList({required this.entries, required this.onTap});

  final List<_Entry> entries;
  final ValueChanged<_Entry> onTap;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Text('Nothing scheduled for this day',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    final timeFormat = DateFormat('h:mm a');

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final entry = entries[i];
        final isEvent = entry.event != null;
        final color = isEvent
            ? colorFromHex(entry.event!.color)
            : entry.task!.priority.color;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () => onTap(entry),
            leading: CircleAvatar(radius: 6, backgroundColor: color),
            title: Text(entry.item.title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${timeFormat.format(entry.item.start)} - ${timeFormat.format(entry.item.end)}',
            ),
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isEvent ? 'Event' : 'Task',
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
      },
    );
  }
}