import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/category.dart';
import '../domain/subtask.dart';
import '../domain/task.dart';
import '../domain/task_enums.dart';

class TasksRepository {
  TasksRepository(this._client);

  final SupabaseClient _client;

  // ---------- Tasks ----------

  Future<List<Task>> fetchTasks() async {
    final data = await _client
        .from('tasks')
        .select()
        .order('created_at', ascending: false);
    return data.map<Task>((row) => Task.fromMap(row)).toList();
  }

  Future<void> addTask(Task task) async {
    await _client.from('tasks').insert(task.toMap());
  }

  Future<void> updateTask(Task task) async {
    await _client.from('tasks').update(task.toMap()).eq('id', task.id);
  }

  Future<void> updateStatus(String taskId, TaskStatus status) async {
    await _client
        .from('tasks')
        .update({'status': status.value}).eq('id', taskId);
  }

  Future<void> deleteTask(String taskId) async {
    await _client.from('tasks').delete().eq('id', taskId);
  }

  // ---------- Categories ----------

  Future<List<Category>> fetchCategories() async {
    final data = await _client.from('categories').select().order('created_at');
    return data.map<Category>((row) => Category.fromMap(row)).toList();
  }

  // ---------- Subtasks ----------

  Future<List<Subtask>> fetchSubtasks(String taskId) async {
    final data = await _client
        .from('subtasks')
        .select()
        .eq('task_id', taskId)
        .order('created_at');
    return data.map<Subtask>((row) => Subtask.fromMap(row)).toList();
  }

  /// All subtasks of the user (used for progress on the list/cards).
  Future<List<Subtask>> fetchAllSubtasks() async {
    final data = await _client.from('subtasks').select().order('created_at');
    return data.map<Subtask>((row) => Subtask.fromMap(row)).toList();
  }

  Future<void> addSubtask(String taskId, String title) async {
    await _client.from('subtasks').insert({'task_id': taskId, 'title': title});
  }

  Future<void> setSubtaskCompleted(String subtaskId, bool completed) async {
    await _client
        .from('subtasks')
        .update({'is_completed': completed}).eq('id', subtaskId);
  }

  Future<void> deleteSubtask(String subtaskId) async {
    await _client.from('subtasks').delete().eq('id', subtaskId);
  }

    /// Sets (or clears, when both are null) the scheduled time of a task.
  Future<void> scheduleTask(
    String taskId, {
    required DateTime? start,
    required DateTime? end,
  }) async {
    await _client.from('tasks').update({
      'start_time': start?.toUtc().toIso8601String(),
      'end_time': end?.toUtc().toIso8601String(),
    }).eq('id', taskId);
  }
}

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository(ref.watch(supabaseClientProvider));
});