import 'task_enums.dart';

class Task {
  const Task({
    required this.id,
    required this.title,
    this.description,
    this.categoryId,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.pending,
    this.deadline,
    this.estimatedDurationMinutes,
    this.startTime,
    this.endTime,
    this.recurrence = Recurrence.none,
  });

  final String id;
  final String title;
  final String? description;
  final String? categoryId;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime? deadline;
  final int? estimatedDurationMinutes;
  final DateTime? startTime;
  final DateTime? endTime;
  final Recurrence recurrence;

  /// Overdue = has a deadline in the past and is not completed.
  bool get isOverdue =>
      deadline != null &&
      status != TaskStatus.completed &&
      deadline!.isBefore(DateTime.now());

  bool get isScheduled => startTime != null && endTime != null;

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      categoryId: map['category_id'] as String?,
      priority: TaskPriority.fromValue(map['priority'] as String),
      status: TaskStatus.fromValue(map['status'] as String),
      deadline: _parseDate(map['deadline']),
      estimatedDurationMinutes: map['estimated_duration_minutes'] as int?,
      startTime: _parseDate(map['start_time']),
      endTime: _parseDate(map['end_time']),
      recurrence: Recurrence.fromValue(map['recurrence'] as String),
    );
  }

  /// Map used for insert/update. `user_id` is filled by the database default.
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category_id': categoryId,
      'priority': priority.value,
      'status': status.value,
      'deadline': deadline?.toUtc().toIso8601String(),
      'estimated_duration_minutes': estimatedDurationMinutes,
      'start_time': startTime?.toUtc().toIso8601String(),
      'end_time': endTime?.toUtc().toIso8601String(),
      'recurrence': recurrence.value,
    };
  }

  Task copyWith({
    String? title,
    String? description,
    String? categoryId,
    TaskPriority? priority,
    TaskStatus? status,
    DateTime? deadline,
    int? estimatedDurationMinutes,
    DateTime? startTime,
    DateTime? endTime,
    Recurrence? recurrence,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      deadline: deadline ?? this.deadline,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      recurrence: recurrence ?? this.recurrence,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.parse(value as String).toLocal();
  }
}