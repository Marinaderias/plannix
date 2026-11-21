import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
  late final TextEditingController _durationController;

  String? _categoryId;
  late TaskPriority _priority;
  late TaskStatus _status;
  late Recurrence _recurrence;
  DateTime? _deadline;
  bool _isSaving = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController =
        TextEditingController(text: task?.description ?? '');
    _durationController = TextEditingController(
      text: task?.estimatedDurationMinutes?.toString() ?? '',
    );
    _categoryId = task?.categoryId;
    _priority = task?.priority ?? TaskPriority.medium;
    _status = task?.status ?? TaskStatus.pending;
    _recurrence = task?.recurrence ?? Recurrence.none;
    _deadline = task?.deadline;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
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
      _deadline = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final description = _descriptionController.text.trim();
    final duration = int.tryParse(_durationController.text.trim());

    final task = Task(
      id: widget.task?.id ?? '',
      title: _titleController.text.trim(),
      description: description.isEmpty ? null : description,
      categoryId: _categoryId,
      priority: _priority,
      status: _status,
      deadline: _deadline,
      estimatedDurationMinutes: duration,
      // Keep the scheduled time if the task already has one.
      startTime: widget.task?.startTime,
      endTime: widget.task?.endTime,
      recurrence: _recurrence,
    );

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(tasksRepositoryProvider);
      if (_isEditing) {
        await repo.updateTask(task);
      } else {
        await repo.addTask(task);
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
      appBar: AppBar(title: Text(_isEditing ? 'Edit Task' : 'New Task')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter a title'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Could not load categories'),
                data: (categories) => DropdownButtonFormField<String?>(
                  initialValue: categories.any((c) => c.id == _categoryId)
                      ? _categoryId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
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
              DropdownButtonFormField<TaskPriority>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final p in TaskPriority.values)
                    DropdownMenuItem(value: p, child: Text(p.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _priority = value);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TaskStatus>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final s in TaskStatus.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDeadline,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Deadline (optional)',
                    border: const OutlineInputBorder(),
                    suffixIcon: _deadline == null
                        ? const Icon(Icons.calendar_today_outlined)
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _deadline = null),
                          ),
                  ),
                  child: Text(
                    _deadline == null
                        ? 'No deadline'
                        : DateFormat('EEE, d MMM yyyy • h:mm a')
                            .format(_deadline!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Estimated duration (minutes, optional)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  final number = int.tryParse(text);
                  if (number == null || number <= 0) {
                    return 'Enter a number greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Recurrence>(
                initialValue: _recurrence,
                decoration: const InputDecoration(
                  labelText: 'Repeat',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final r in Recurrence.values)
                    DropdownMenuItem(value: r, child: Text(r.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _recurrence = value);
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditing ? 'Save Changes' : 'Add Task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}