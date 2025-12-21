import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/lead_model.dart';
import 'database_service.dart';

class TaskService extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  List<Task> _tasks = [];
  bool _isLoading = false;

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;

  TaskService() {
    loadTasks();
  }

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();
    try {
      final taskMaps = await _dbService.getTasks();
      _tasks = taskMaps.map((map) => Task.fromMap(map)).toList();
      // Sort by ID descending (newest tasks first)
      _tasks.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTaskForLead(Lead lead) async {
    final newTask = Task(
      title: 'Follow up with ${lead.name}',
      description: 'Newly added lead, requires follow-up.',
      dueDate: DateTime.now().add(const Duration(days: 2)),
      category: lead.category,
      priority: 'medium',
      isCompleted: false,
      leadId: lead.id,
    );
    await addTask(newTask);
  }

  Future<void> addTask(Task task) async {
    try {
      final id = await _dbService.insertTask(task.toMap());
      // Add new task at the beginning of the list (newest first)
      final savedTask = task.copyWith(id: id);
      _tasks.insert(0, savedTask); // Insert at beginning instead of add at end
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding task: $e');
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      if (task.id == null) return;
      await _dbService.updateTask(task.toMap());
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = task;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating task: $e');
    }
  }

  Future<void> deleteTask(int id) async {
    try {
      await _dbService.deleteTask(id);
      _tasks.removeWhere((t) => t.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }
}
