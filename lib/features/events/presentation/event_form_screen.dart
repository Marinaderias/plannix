import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/scheduling/scheduled_item.dart';
import '../../../core/scheduling/scheduling_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../tasks/data/tasks_providers.dart';
import '../data/events_repository.dart';
import '../domain/event.dart';

const _eventColors = <String>[
  '#7C3AED', // purple
  '#3B82F6', // blue
  '#14B8A6', // teal
  '#F59E0B', // amber
  '#F97316', // orange
  '#EC4899', // pink
];

Color colorFromHex(String? hex) {
  if (hex == null || hex.length != 7) return AppColors.purple;
  final value = int.tryParse(hex.substring(1), radix: 16);
  return value == null ? AppColors.purple : Color(0xFF000000 | value);
}

class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, this.event, this.initialDate});

  /// null = add mode, not null = edit mode.
  final Event? event;

  /// Default day for a new event.
  final DateTime? initialDate;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;

  late DateTime _start;
  late DateTime _end;
  late String _color;
  bool _isSaving = false;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _titleController = TextEditingController(text: event?.title ?? '');
    _locationController = TextEditingController(text: event?.location ?? '');

    if (event != null) {
      _start = event.startTime;
      _end = event.endTime;
    } else {
      final base = widget.initialDate ?? DateTime.now();
      final nextHour = DateTime(base.year, base.month, base.day,
          DateTime.now().hour + 1);
      _start = nextHour;
      _end = nextHour.add(const Duration(hours: 1));
    }
    _color = event?.color ?? _eventColors.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (date == null) return;

    setState(() {
      if (isStart) {
        final duration = _end.difference(_start);
        _start = DateTime(
            date.year, date.month, date.day, _start.hour, _start.minute);
        _end = _start.add(duration);
      } else {
        _end = DateTime(
            date.year, date.month, date.day, _end.hour, _end.minute);
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;

    setState(() {
      if (isStart) {
        final duration = _end.difference(_start);
        _start = DateTime(
            _start.year, _start.month, _start.day, time.hour, time.minute);
        _end = _start.add(duration);
      } else {
        _end = DateTime(
            _end.year, _end.month, _end.day, time.hour, time.minute);
      }
    });
  }

  /// Returns true if the user wants to continue saving.
  Future<bool> _confirmConflicts() async {
    final events = ref.read(eventsProvider).value ?? [];
    final tasks = ref.read(tasksProvider).value ?? [];

    final items = <ScheduledItem>[
      for (final e in events) ScheduledItem.fromEvent(e),
      for (final t in tasks)
        if (ScheduledItem.fromTask(t) != null) ScheduledItem.fromTask(t)!,
    ];

    final conflicts = SchedulingService.findConflicts(
      start: _start,
      end: _end,
      items: items,
      excludeId: widget.event?.id,
    );
    if (conflicts.isEmpty) return true;

    final format = DateFormat('h:mm a');
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scheduling conflict'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This overlaps with:'),
            const SizedBox(height: 8),
            for (final c in conflicts)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${c.title} (${format.format(c.start)} - ${format.format(c.end)})',
                ),
              ),
          ],
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_end.isAfter(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after the start time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!await _confirmConflicts()) return;
    if (!mounted) return;

    final location = _locationController.text.trim();
    final event = Event(
      id: widget.event?.id ?? '',
      title: _titleController.text.trim(),
      description: widget.event?.description,
      location: location.isEmpty ? null : location,
      color: _color,
      startTime: _start,
      endTime: _end,
    );

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(eventsRepositoryProvider);
      if (_isEditing) {
        await repo.updateEvent(event);
      } else {
        await repo.addEvent(event);
      }
      ref.invalidate(eventsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the event. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('"${widget.event!.title}" will be deleted permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(eventsRepositoryProvider).deleteEvent(widget.event!.id);
      ref.invalidate(eventsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete the event'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y');
    final timeFormat = DateFormat('h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Event' : 'Add Event'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _Label('Event Title'),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'e.g. Team Meeting'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter a title'
                    : null,
              ),
              const SizedBox(height: 16),
              const _Label('Location'),
              TextFormField(
                controller: _locationController,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    const InputDecoration(hintText: 'e.g. Office / Zoom'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'Start Date',
                      icon: Icons.calendar_today_outlined,
                      text: dateFormat.format(_start),
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      label: 'Start Time',
                      icon: Icons.access_time,
                      text: timeFormat.format(_start),
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'End Date',
                      icon: Icons.calendar_today_outlined,
                      text: dateFormat.format(_end),
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      label: 'End Time',
                      icon: Icons.access_time,
                      text: timeFormat.format(_end),
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _Label('Color'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final hex in _eventColors)
                    GestureDetector(
                      onTap: () => setState(() => _color = hex),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorFromHex(hex),
                          shape: BoxShape.circle,
                          border: _color == hex
                              ? Border.all(
                                  color: AppColors.textDark, width: 2.5)
                              : null,
                        ),
                        child: _color == hex
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 18)
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              GradientButton(
                label: _isEditing ? 'Save Changes' : 'Add Event',
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(text, overflow: TextOverflow.ellipsis),
                ),
                Icon(icon, size: 18, color: AppColors.purple),
              ],
            ),
          ),
        ),
      ],
    );
  }
}