import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tasks_filter.dart';
import '../data/tasks_providers.dart';
import '../data/tasks_repository.dart';
import '../domain/task.dart';
import '../domain/task_enums.dart';
import 'task_form_screen.dart';
import 'widgets/filter_bar.dart';
import 'widgets/task_card.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    Task task,
    TaskStatus status,
  ) async {
    try {
      await ref.read(tasksRepositoryProvider).updateStatus(task.id, status);
      ref.invalidate(tasksProvider);
    } catch (_) {
      if (context.mounted) _showError(context, 'Could not update the task');
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${task.title}" will be deleted permanently.'),
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
      await ref.read(tasksRepositoryProvider).deleteTask(task.id);
      ref.invalidate(tasksProvider);
    } catch (_) {
      if (context.mounted) _showError(context, 'Could not delete the task');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(filteredTasksProvider);
    final filter = ref.watch(tasksFilterProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) {
        debugPrint('TASKS ERROR: $e');
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Failed to load tasks'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(tasksProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
      data: (tasks) {
        return Column(
          children: [
            const FilterBar(),
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Text(
                        filter.isActive
                            ? 'No tasks match these filters.'
                            : 'No tasks yet.\nTap + to add your first one.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(tasksProvider);
                        await ref.read(tasksProvider.future);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 88),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return TaskCard(
                            task: task,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TaskFormScreen(task: task),
                              ),
                            ),
                            onStatusChanged: (status) =>
                                _changeStatus(context, ref, task, status),
                            onDelete: () => _delete(context, ref, task),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}