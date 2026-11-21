import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/task.dart';
import '../../domain/task_enums.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.categoryName,
    required this.onTap,
    required this.onStatusChanged,
    required this.onDelete,
  });

  final Task task;
  final String? categoryName;
  final VoidCallback onTap;
  final ValueChanged<TaskStatus> onStatusChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == TaskStatus.completed;
    final priorityColor = task.priority.color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 5, color: priorityColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isCompleted
                                      ? AppColors.textMuted
                                      : AppColors.textDark,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle,
                                    size: 8, color: priorityColor),
                                const SizedBox(width: 4),
                                Text(
                                  task.priority.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: priorityColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (categoryName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            categoryName!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.purple,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (task.deadline != null)
                              Text(
                                DateFormat('MMM d, h:mm a')
                                    .format(task.deadline!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: task.isOverdue
                                      ? Colors.red
                                      : AppColors.textMuted,
                                ),
                              ),
                            if (task.isOverdue)
                              const Text(
                                'Overdue',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (task.status == TaskStatus.inProgress)
                              const Text(
                                'In Progress',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Completion circle.
                InkWell(
                  onTap: () => onStatusChanged(
                    isCompleted ? TaskStatus.pending : TaskStatus.completed,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(
                      child: Icon(
                        isCompleted
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isCompleted
                            ? AppColors.purple
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      size: 20, color: AppColors.textMuted),
                  onSelected: (value) {
                    if (value == 'delete') {
                      onDelete();
                    } else {
                      onStatusChanged(TaskStatus.fromValue(value));
                    }
                  },
                  itemBuilder: (_) => [
                    for (final status in TaskStatus.values)
                      PopupMenuItem(
                        value: status.value,
                        child: Text('Mark as ${status.label}'),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}