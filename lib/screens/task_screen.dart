import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../services/task_service.dart';
import '../services/label_service.dart';
import '../widgets/bottom_nav_bar.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  TasksScreenState createState() => TasksScreenState();
}

class TasksScreenState extends State<TasksScreen> {
  final int _currentIndex = 2;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: const Text('Tasks', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _showAddTaskDialog(),
          ),
        ],
      ),
      body: Consumer<TaskService>(
        builder: (context, taskService, child) {
          // Filter tasks by search query
          var tasks = taskService.tasks;
          if (_searchQuery.isNotEmpty) {
            tasks = tasks.where((task) {
              return task.title.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  task.description.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  );
            }).toList();
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildSearchBar()),
              SliverToBoxAdapter(child: const SizedBox(height: 16)),
              SliverToBoxAdapter(child: _buildFilterSection()),
              SliverToBoxAdapter(child: const SizedBox(height: 16)),
              SliverToBoxAdapter(child: _buildTaskStats(tasks)),
              SliverPadding(
                padding: const EdgeInsets.only(top: 16),
                sliver: _buildTasksList(tasks),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index != _currentIndex) {
            Navigator.pushReplacementNamed(context, _getRouteName(index));
          }
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search tasks...',
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF2A2A3E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      height: 50,
      margin: const EdgeInsets.all(16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('All Tasks', 'all'),
          _buildFilterChip('Today', 'today'),
          _buildFilterChip('This Week', 'week'),
          _buildFilterChip('High Priority', 'high'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
        },
        backgroundColor: const Color(0xFF2A2A3E),
        selectedColor: const Color(0xFF6C5CE7),
        side: BorderSide.none,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey),
      ),
    );
  }

  Widget _buildTaskStats(List<Task> tasks) {
    final totalTasks = tasks.length;
    final completedTasks = tasks.where((t) => t.isCompleted).length;
    final pendingTasks = totalTasks - completedTasks;
    final overdueTasks = tasks
        .where((t) => !t.isCompleted && t.dueDate.isBefore(DateTime.now()))
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total',
              totalTasks.toString(),
              Icons.assignment,
              const Color(0xFF6C5CE7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Pending',
              pendingTasks.toString(),
              Icons.pending_actions,
              const Color(0xFFFF6B6B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Overdue',
              overdueTasks.toString(),
              Icons.warning,
              const Color(0xFFFFB86C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTasksList(List<Task> tasks) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final task = tasks[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildTaskItem(task),
        );
      }, childCount: tasks.length),
    );
  }

  Widget _buildTaskItem(Task task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (value) {
            final updatedTask = task.copyWith(isCompleted: value!);
            context.read<TaskService>().updateTask(updatedTask);
          },
          checkColor: Colors.white,
          activeColor: const Color(0xFF6C5CE7),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            color: Colors.white,
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.description,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (task.leadId != null) ...[
              const SizedBox(height: 4),
              const Row(
                children: [
                  Icon(Icons.person, color: Colors.grey, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'Linked to Lead', // Placeholder until we fetch lead name
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                _buildTaskChip(task.category),
                const SizedBox(width: 8),
                _buildPriorityChip(task.priority),
                if (task.reminder != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.notifications, color: Colors.grey, size: 12),
                ],
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _formatDueDate(task.dueDate, task.dueTime),
                    style: TextStyle(
                      color: task.dueDate.isBefore(DateTime.now())
                          ? Colors.red
                          : Colors.grey,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF6C5CE7), size: 20),
              onPressed: () {
                _showEditTaskDialog(task);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () {
                _showDeleteConfirmation(task);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTaskDialog(Task task) {
    final titleController = TextEditingController(text: task.title);
    final descriptionController = TextEditingController(text: task.description);
    DateTime selectedDate = task.dueDate;
    TimeOfDay? selectedTime = task.dueTime;
    DateTime? reminderDate = task.reminder;
    String selectedCategory = task.category;
    String selectedPriority = task.priority;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A3E),
          title: const Text('Edit Task', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF1A1A2E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C5CE7),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF1A1A2E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C5CE7),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Consumer<LabelService>(
                      builder: (context, labelService, child) {
                        // Ensure selectedCategory is valid for current labels
                        if (!labelService.labels.any(
                          (l) => l.name == selectedCategory,
                        )) {
                          selectedCategory = labelService.labels.isNotEmpty
                              ? labelService.labels.first.name
                              : 'General';
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          dropdownColor: const Color(0xFF1A1A2E),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Category',
                            labelStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF1A1A2E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: labelService.labels
                              .map(
                                (label) => DropdownMenuItem(
                                  value: label.name,
                                  child: Text(label.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                selectedCategory = value;
                              });
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPriority,
                      dropdownColor: const Color(0xFF1A1A2E),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF1A1A2E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: ['high', 'medium', 'low']
                          .map(
                            (priority) => DropdownMenuItem(
                              value: priority,
                              child: Text(priority),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedPriority = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(
                        'Due Date: ${"${selectedDate.toLocal()}".split(' ')[0]}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.calendar_today,
                        color: Colors.grey,
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2101),
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: Text(
                        'Due Time: ${selectedTime != null ? selectedTime!.format(context) : 'Not set'}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.access_time,
                        color: Colors.grey,
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            selectedTime = time;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: Text(
                        'Reminder: ${reminderDate != null ? "${reminderDate!.toLocal()}".split(' ')[0] : 'Not set'}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.notifications,
                        color: Colors.grey,
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: reminderDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2101),
                        );
                        if (date == null) return;

                        if (!context.mounted) return;

                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            reminderDate = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  final updatedTask = task.copyWith(
                    title: titleController.text,
                    description: descriptionController.text,
                    dueDate: selectedDate,
                    dueTime: selectedTime,
                    category: selectedCategory,
                    priority: selectedPriority,
                    reminder: reminderDate,
                  );
                  context.read<TaskService>().updateTask(updatedTask);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Task updated'),
                      backgroundColor: Color(0xFF6C5CE7),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text('Delete Task', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${task.title}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<TaskService>().deleteTask(task.id!);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Task deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskChip(String category) {
    final colors = {
      'jobs': const Color(0xFF4ECDC4),
      'internship': const Color(0xFFA29BFE),
      'paid_internship': const Color(0xFF6C5CE7),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors[category] ?? Colors.grey,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    final colors = {
      'high': Colors.red,
      'medium': Colors.orange,
      'low': Colors.green,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors[priority]?.withAlpha((255 * 0.2).round()) ?? Colors.grey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          color: colors[priority] ?? Colors.grey,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDueDate(DateTime date, TimeOfDay? time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final dueDate = DateTime(date.year, date.month, date.day);

    String dayText;
    if (dueDate == today) {
      dayText = 'Today';
    } else if (dueDate == tomorrow) {
      dayText = 'Tomorrow';
    } else {
      dayText = '${date.day}/${date.month}/${date.year}';
    }

    if (time != null) {
      return '$dayText at ${time.format(context)}';
    }
    return dayText;
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime? selectedDate = DateTime.now();
    TimeOfDay? selectedTime = TimeOfDay.now();
    DateTime? reminderDate;
    String? selectedCategory; // Will be set from labels
    String selectedPriority = 'medium';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A3E),
          title: const Text(
            'Add New Task',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Title',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF1A1A2E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C5CE7),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF1A1A2E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C5CE7),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    Consumer<LabelService>(
                      builder: (context, labelService, child) {
                        if (labelService.labels.isEmpty) {
                          return const Text(
                            'Please create labels in Settings first',
                            style: TextStyle(color: Colors.orange),
                          );
                        }

                        // Initialize with first label if not set
                        if (selectedCategory == null ||
                            !labelService.labels.any(
                              (l) => l.name == selectedCategory,
                            )) {
                          selectedCategory = labelService.labels.first.name;
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          dropdownColor: const Color(0xFF1A1A2E),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Category',
                            labelStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF1A1A2E),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: labelService.labels
                              .map(
                                (label) => DropdownMenuItem(
                                  value: label.name,
                                  child: Text(label.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                selectedCategory = value;
                              });
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedPriority,
                      dropdownColor: const Color(0xFF1A1A2E),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color(0xFF1A1A2E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: ['high', 'medium', 'low']
                          .map(
                            (priority) => DropdownMenuItem(
                              value: priority,
                              child: Text(priority),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedPriority = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(
                        'Due Date: ${selectedDate != null ? "${selectedDate!.toLocal()}".split(' ')[0] : 'Not set'}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.calendar_today,
                        color: Colors.grey,
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2101),
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: Text(
                        'Due Time: ${selectedTime != null ? selectedTime!.format(context) : 'Not set'}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.access_time,
                        color: Colors.grey,
                      ),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            selectedTime = time;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: Text(
                        'Reminder: ${reminderDate != null ? "${reminderDate!.toLocal()}".split(' ')[0] : 'Not set'}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.notifications,
                        color: Colors.grey,
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: reminderDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2101),
                        );
                        if (date == null) return; // Guard clause

                        // Because of the lint rule `use_build_context_synchronously`,
                        // we need to check if the widget is still mounted before calling `showTimePicker`.
                        if (!context.mounted) return;

                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            reminderDate = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white, // Makes text white
              ),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
              onPressed: () {
                if (titleController.text.isNotEmpty && selectedDate != null) {
                  // Get labels to ensure category has a valid value
                  final labelService = Provider.of<LabelService>(
                    context,
                    listen: false,
                  );
                  final category =
                      selectedCategory ??
                      (labelService.labels.isNotEmpty
                          ? labelService.labels.first.name
                          : 'General');

                  final newTask = Task(
                    title: titleController.text,
                    description: descriptionController.text,
                    dueDate: selectedDate!,
                    dueTime: selectedTime,
                    category: category,
                    priority: selectedPriority,
                    isCompleted: false,
                    reminder: reminderDate,
                  );
                  context.read<TaskService>().addTask(newTask);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  String _getRouteName(int index) {
    switch (index) {
      case 0:
        return '/dashboard';
      case 1:
        return '/leads';
      case 2:
        return '/tasks';
      case 3:
        return '/settings';
      default:
        return '/dashboard';
    }
  }
}
