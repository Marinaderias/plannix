import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/scheduling/scheduled_item.dart';
import '../../../core/scheduling/scheduling_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/reminder_options.dart';
import '../../../core/theme/app_theme.dart';
import '../../events/data/events_repository.dart';
import '../data/tasks_providers.dart';
import '../data/tasks_repository.dart';
import '../domain/task.dart';
import '../domain/task_enums.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.task});

  /// null = add mode, not null = edit mode.
  final Task? task;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  String? _categoryId;
  late TaskPriority _priority;
  late TaskStatus _status;
  late Recurrence _recurrence;
  DateTime? _deadline;
  int? _durationMinutes;
  DateTime? _scheduledStart;
  int? _reminder;
  bool _isSaving = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    _categoryId = task?.categoryId;
    _priority = task?.priority ?? TaskPriority.medium;
    _status = task?.status ?? TaskStatus.pending;
    _recurrence = task?.recurrence ?? Recurrence.none;
    _deadline = task?.deadline;
    _durationMinutes = task?.estimatedDurationMinutes;
    _scheduledStart = task?.startTime;
    _reminder = task?.reminderMinutes;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final initial = _deadline ?? now;

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

    setState(() {
      _deadline = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickScheduledStart() async {
    final now = DateTime.now();
    final initial = _scheduledStart ?? now;

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

    setState(() {
      _scheduledStart = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  DateTime? get _scheduledEnd => _scheduledStart?.add(
        Duration(minutes: _durationMinutes ?? 60),
      );

  /// Returns true if the user wants to continue saving.
  Future<bool> _confirmConflicts() async {
    final start = _scheduledStart;
    final end = _scheduledEnd;
    if (start == null || end == null) return true;

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
      excludeId: widget.task?.id,
    );
    if (conflicts.isEmpty) return true;

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
    return proceed == true;
  }

  Future<void> _pickDuration() async {
    final current = _durationMinutes ?? 60;
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _DurationDialog(initialMinutes: current),
    );
    if (result != null) setState(() => _durationMinutes = result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!await _confirmConflicts()) return;
    if (!mounted) return;

    final description = _descriptionController.text.trim();

    final task = Task(
      id: widget.task?.id ?? '',
      title: _titleController.text.trim(),
      description: description.isEmpty ? null : description,
      categoryId: _categoryId,
      priority: _priority,
      status: _status,
      deadline: _deadline,
      estimatedDurationMinutes: _durationMinutes,
      startTime: _scheduledStart,
      endTime: _scheduledEnd,
      recurrence: _recurrence,
      reminderMinutes: _reminder,
    );

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(tasksRepositoryProvider);
      String id = task.id;
      if (_isEditing) {
        await repo.updateTask(task);
      } else {
        id = await repo.addTask(task);
      }

      await NotificationService.cancel('task_$id');
      final base = _scheduledStart ?? _deadline;
      if (_reminder != null && base != null) {
        await NotificationService.schedule(
          key: 'task_$id',
          title: task.title,
          body: _scheduledStart != null
              ? 'Time to start'
              : 'Deadline approaching',
          at: base.subtract(Duration(minutes: _reminder!)),
        );
      }

      ref.invalidate(tasksProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the task. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Task' : 'Add New Task')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _Label('Title'),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'e.g. Complete project report',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter a title'
                    : null,
              ),
              const SizedBox(height: 16),
              const _Label('Description'),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Add task description...',
                ),
              ),
              const SizedBox(height: 16),
              const _Label('Category'),
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Could not load categories'),
                data: (categories) => DropdownButtonFormField<String?>(
                  initialValue: categories.any((c) => c.id == _categoryId)
                      ? _categoryId
                      : null,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No category'),
                    ),
                    for (final c in categories)
                      DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(c.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
              ),
              const SizedBox(height: 16),
              const _Label('Priority'),
              Row(
                children: [
                  for (final p in TaskPriority.values)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: p == TaskPriority.low ? 0 : 8,
                        ),
                        child: _PriorityButton(
                          priority: p,
                          selected: _priority == p,
                          onTap: () => setState(() => _priority = p),
                        ),
                      ),
                    ),
                ],
              ),
              if (_isEditing) ...[
                const SizedBox(height: 16),
                const _Label('Status'),
                DropdownButtonFormField<TaskStatus>(
                  initialValue: _status,
                  items: [
                    for (final s in TaskStatus.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _status = value);
                  },
                ),
              ],
              const SizedBox(height: 16),
              const _Label('Deadline'),
              _PickerField(
                icon: Icons.calendar_today_outlined,
                text: _deadline == null
                    ? 'No deadline'
                    : DateFormat('MMM d, y   h:mm a').format(_deadline!),
                onTap: _pickDeadline,
                onClear: _deadline == null
                    ? null
                    : () => setState(() => _deadline = null),
              ),
              const SizedBox(height: 16),
              const _Label('Estimated Duration'),
              _PickerField(
                icon: Icons.access_time,
                text: _durationMinutes == null
                    ? 'Not set'
                    : _formatDuration(_durationMinutes!),
                onTap: _pickDuration,
                onClear: _durationMinutes == null
                    ? null
                    : () => setState(() => _durationMinutes = null),
              ),
              const SizedBox(height: 16),
              const _Label('Schedule (optional)'),
              _PickerField(
                icon: Icons.event_available_outlined,
                text: _scheduledStart == null
                    ? 'Not scheduled'
                    : '${DateFormat('MMM d, h:mm a').format(_scheduledStart!)} - ${DateFormat('h:mm a').format(_scheduledEnd!)}',
                onTap: _pickScheduledStart,
                onClear: _scheduledStart == null
                    ? null
                    : () => setState(() => _scheduledStart = null),
              ),
              const SizedBox(height: 16),
              const _Label('Reminder'),
              DropdownButtonFormField<int?>(
                initialValue: _reminder,
                items: [
                  for (final e in reminderOptions.entries)
                    DropdownMenuItem<int?>(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _reminder = v),
              ),
              const SizedBox(height: 16),
              const _Label('Repeat'),
              DropdownButtonFormField<Recurrence>(
                initialValue: _recurrence,
                items: [
                  for (final r in Recurrence.values)
                    DropdownMenuItem(
                      value: r,
                      child: Text(
                        r == Recurrence.none ? 'Does not repeat' : r.label,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _recurrence = value);
                },
              ),
              const SizedBox(height: 28),
              GradientButton(
                label: _isEditing ? 'Save Changes' : 'Add Task',
                isLoading: _isSaving,
                onPressed: _save,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _PriorityButton extends StatelessWidget {
  const _PriorityButton({
    required this.priority,
    required this.selected,
    required this.onTap,
  });

  final TaskPriority priority;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = priority.color;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, size: 10, color: color),
            const SizedBox(width: 6),
            Text(
              priority.label,
              style: TextStyle(
                color: selected ? color : AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.text,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.purple),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.clear,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DurationDialog extends StatefulWidget {
  const _DurationDialog({required this.initialMinutes});

  final int initialMinutes;

  @override
  State<_DurationDialog> createState() => _DurationDialogState();
}

class _DurationDialogState extends State<_DurationDialog> {
  late int _hours = (widget.initialMinutes ~/ 60).clamp(0, 12);
  late int _minutes = _snap(widget.initialMinutes % 60);

  static int _snap(int m) => (m ~/ 5) * 5;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Estimated Duration'),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DropdownButton<int>(
            value: _hours,
            items: [
              for (var h = 0; h <= 12; h++)
                DropdownMenuItem(value: h, child: Text('$h h')),
            ],
            onChanged: (v) => setState(() => _hours = v ?? 0),
          ),
          const SizedBox(width: 24),
          DropdownButton<int>(
            value: _minutes,
            items: [
              for (var m = 0; m < 60; m += 5)
                DropdownMenuItem(value: m, child: Text('$m min')),
            ],
            onChanged: (v) => setState(() => _minutes = v ?? 0),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final total = _hours * 60 + _minutes;
            Navigator.pop(context, total == 0 ? null : total);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}