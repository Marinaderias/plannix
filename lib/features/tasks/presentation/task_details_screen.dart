import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
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
    final Task? task = tasksAsync.value
        ?.where((t) => t.id == widget.taskId)
        .firstOrNull;

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
                      value: categoryName ?? '—'),
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
                        : DateFormat('MMM d, y, h:mm a')
                            .format(task.deadline!),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Subtasks',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
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
              Text('${(progress * 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
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