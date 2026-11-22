class Subtask {
  const Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    this.isCompleted = false,
  });

  final String id;
  final String taskId;
  final String title;
  final bool isCompleted;

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      title: map['title'] as String,
      isCompleted: map['is_completed'] as bool? ?? false,
    );
  }
}
