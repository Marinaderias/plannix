import 'package:flutter/material.dart';

enum TaskPriority {
  high('high', 'High', Colors.red),
  medium('medium', 'Medium', Colors.orange),
  low('low', 'Low', Colors.green);

  const TaskPriority(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  static TaskPriority fromValue(String value) =>
      TaskPriority.values.firstWhere((e) => e.value == value);
}

enum TaskStatus {
  pending('pending', 'Pending'),
  inProgress('in_progress', 'In Progress'),
  completed('completed', 'Completed');

  const TaskStatus(this.value, this.label);

  final String value;
  final String label;

  static TaskStatus fromValue(String value) =>
      TaskStatus.values.firstWhere((e) => e.value == value);
}

enum Recurrence {
  none('none', 'None'),
  daily('daily', 'Daily'),
  weekly('weekly', 'Weekly'),
  monthly('monthly', 'Monthly');

  const Recurrence(this.value, this.label);

  final String value;
  final String label;

  static Recurrence fromValue(String value) =>
      Recurrence.values.firstWhere((e) => e.value == value);
}
