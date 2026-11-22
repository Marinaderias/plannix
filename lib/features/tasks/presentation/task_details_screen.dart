import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/scheduling/scheduled_item.dart';
import '../../../core/scheduling/scheduling_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../events/data/events_repository.dart';
import '../data/tasks_providers.dart';
import '../data/tasks_repository.dart';
import '../domain/task.dart';
import 'task_form_screen.dart';

class TaskDetailsScreen extends ConsumerStatefulWidget {
  const TaskDetailsScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends ConsumerState<TaskDetailsScreen> {
  final _subtaskController = TextEditingController();

  @override
  void dispose() {
    _subtaskController.dispose();
    super.dispose();
  }

  Future<void> _addSubtask() async {
    final title = _subtaskController.text.trim();
    if (title.isEmpty) return;
    _subtaskController.clear();
    try {
      await ref.read(tasksRepositoryProvider).addSubtask(widget.taskId, title);
      ref.invalidate(subtasksProvider(widget.taskId));
    } catch (_) {
      _showError('Could not add the subtask');
    }
  }

  Future<void> _toggle(String id, bool value) async {
    try {
      await ref.read(tasksRepositoryProvider).setSubtaskCompleted(id, value);
      ref.invalidate(subtasksProvider(widget.taskId));
    } catch (_) {
      _showError('Could not update the subtask');
    }
  }

  Future<void> _deleteSubtask(String id) async {
    try {
      await ref.read(tasksRepositoryProvider).deleteSubtask(id);
      ref.invalidate(subtasksProvider(widget.taskId));
    } catch (_) {
      _showError('Could not delete the subtask');
    }
  }

  Future<void> _schedule(Task task) async {
    final now = DateTime.now();
    final initial = task.startTime ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;

    final start =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final end =
        start.add(Duration(minutes: task.estimatedDurationMinutes ?? 60));

    // Conflict check against events and other scheduled tasks.
    final events = ref.read(eventsProvider).value ?? [];
    final tasks = ref.read(tasksProvider).value ?? [];
    final items = <ScheduledItem>[
      for (final e in events) ScheduledItem.fromEvent(e),
      for (final t in tasks)
        if (ScheduledItem.fromTask(t) != null) ScheduledItem.fromTask(t)!,
    ];
    final conflicts = SchedulingService.findConflicts(
      start: start,
      end: end,
      items: items,
      excludeId: task.id,
    );

    if (conflicts.isNotEmpty) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Scheduling conflict'),
          content: Text(
            'This overlaps with: ${conflicts.map((c) => c.title).join(', ')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    try {
      await ref
          .read(tasksRepositoryProvider)
          .scheduleTask(task.id, start: start, end: end);
      ref.invalidate(tasksProvider);
    } catch (_) {
      _showError('Could not schedule the task');
    }
  }

  Future<void> _unschedule(Task task) async {
    try {
      await ref
          .read(tasksRepositoryProvider)
          .scheduleTask(task.id, start: null, end: null);
      ref.invalidate(tasksProvider);
    } catch (_) {
      _showError('Could not clear the schedule');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);
    final categories = ref.watch(categoriesProvider).value ?? [];
    final subtasksAsync = ref.watch(subtasksProvider(widget.taskId));

    // The task may disappear (deleted); handle it gracefully.
    final Task? task =
        tasksAsync.value?.where((t) => t.id == widget.taskId).firstOrNull;

    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: tasksAsync.isLoading
              ? const CircularProgressIndicator()
              : const Text('Task not found'),
        ),
      );
    }

    final categoryName = categories
        .where((c) => c.id == task.categoryId)
        .map((c) => c.name)
        .firstOrNull;

    final subtasks = subtasksAsync.value ?? [];
    final doneCount = subtasks.where((s) => s.isCompleted).length;
    final progress = subtasks.isEmpty ? 0.0 : doneCount / subtasks.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  task.status.label,
                  style: const TextStyle(
                    color: AppColors.purple,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (task.description != null) ...[
            const SizedBox(height: 8),
            Text(task.description!,
                style: const TextStyle(color: AppColors.textMuted)),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.folder_outlined,
                    label: 'Category',
                    value: categoryName ?? '—',
                  ),
                  _InfoRow(
                    icon: Icons.flag_outlined,
                    label: 'Priority',
                    value: task.priority.label,
                    valueColor: task.priority.color,
                  ),
                  _InfoRow(
                    icon: Icons.event_outlined,
                    label: 'Deadline',
                    value: task.deadline == null
                        ? '—'
                        : DateFormat('MMM d, y, h:mm a').format(task.deadline!),
                    valueColor: task.isOverdue ? Colors.red : null,
                  ),
                  _InfoRow(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: _formatDuration(task.estimatedDurationMinutes),
                  ),
                  _InfoRow(
                    icon: Icons.repeat,
                    label: 'Repeat',
                    value: task.recurrence.label,
                  ),
                  _InfoRow(
                    icon: Icons.schedule,
                    label: 'Scheduled',
                    value: task.isScheduled
                        ? '${DateFormat('MMM d, h:mm a').format(task.startTime!)} - ${DateFormat('h:mm a').format(task.endTime!)}'
                        : 'Not scheduled',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _schedule(task),
                  icon: const Icon(Icons.schedule),
                  label: Text(task.isScheduled ? 'Reschedule' : 'Schedule'),
                ),
              ),
              if (task.isScheduled) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _unschedule(task),
                  child: const Text('Clear'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                'Subtasks',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '$doneCount / ${subtasks.length}',
                style: const TextStyle(
                  color: AppColors.purple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    color: AppColors.purple,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (subtasksAsync.isLoading && subtasks.isEmpty)
            const Center(child: CircularProgressIndicator())
          else
            for (final s in subtasks)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Checkbox(
                    value: s.isCompleted,
                    shape: const CircleBorder(),
                    onChanged: (v) => _toggle(s.id, v ?? false),
                  ),
                  title: Text(
                    s.title,
                    style: TextStyle(
                      decoration:
                          s.isCompleted ? TextDecoration.lineThrough : null,
                      color: s.isCompleted ? AppColors.textMuted : null,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _deleteSubtask(s.id),
                  ),
                ),
              ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _subtaskController,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _addSubtask(),
                  decoration: const InputDecoration(
                    hintText: 'Add a subtask...',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addSubtask,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static String _formatDuration(int? minutes) {
    if (minutes == null) return '—';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.purple),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}