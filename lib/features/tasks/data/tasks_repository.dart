import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/category.dart';
import '../domain/task.dart';
import '../domain/task_enums.dart';

class TasksRepository {
  TasksRepository(this._client);

  final SupabaseClient _client;

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

  Future<List<Category>> fetchCategories() async {
    final data = await _client.from('categories').select().order('created_at');
    return data.map<Category>((row) => Category.fromMap(row)).toList();
  }
}

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository(ref.watch(supabaseClientProvider));
});