import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/tasks_filter.dart';
import '../../data/tasks_providers.dart';
import '../../domain/task_enums.dart';

class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(tasksFilterProvider);
    final notifier = ref.read(tasksFilterProvider.notifier);
    final categories = ref.watch(categoriesProvider).value ?? [];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (filter.isActive) ...[
            ActionChip(
              avatar: const Icon(Icons.clear, size: 16),
              label: const Text('Clear'),
              onPressed: notifier.clear,
            ),
            const SizedBox(width: 8),
          ],
          _FilterMenu<String>(
            label: 'Category',
            selectedLabel: categories
                .where((c) => c.id == filter.categoryId)
                .map((c) => c.name)
                .firstOrNull,
            options: {for (final c in categories) c.id: c.name},
            onSelected: notifier.setCategory,
          ),
          const SizedBox(width: 8),
          _FilterMenu<TaskPriority>(
            label: 'Priority',
            selectedLabel: filter.priority?.label,
            options: {for (final p in TaskPriority.values) p: p.label},
            onSelected: notifier.setPriority,
          ),
          const SizedBox(width: 8),
          _FilterMenu<TaskStatus>(
            label: 'Status',
            selectedLabel: filter.status?.label,
            options: {for (final s in TaskStatus.values) s: s.label},
            onSelected: notifier.setStatus,
          ),
        ],
      ),
    );
  }
}

class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.selectedLabel,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String? selectedLabel;
  final Map<T, String> options;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedLabel != null;

    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final entry in options.entries)
          PopupMenuItem<T>(value: entry.key, child: Text(entry.value)),
      ],
      child: Chip(
        label: Text(isSelected ? '$label: $selectedLabel' : label),
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        deleteIcon: const Icon(Icons.arrow_drop_down),
        onDeleted: null,
        avatar: null,
      ),
    );
  }
}