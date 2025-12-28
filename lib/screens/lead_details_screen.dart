import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Add intl for dates
import '../models/lead_model.dart';
import '../models/call_history_model.dart';
import '../models/task_model.dart';
import '../models/communication_model.dart';
import '../services/database_service.dart';
import '../services/label_service.dart';
import '../services/task_service.dart';
import 'package:url_launcher/url_launcher.dart';

class LeadDetailScreen extends StatefulWidget {
  final Lead lead;

  const LeadDetailScreen({super.key, required this.lead});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  late Lead _lead;
  final DatabaseService _dbService = DatabaseService();
  final List<TimelineItem> _timelineItems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _lead = widget.lead;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final leadId = _lead.id!;
      _timelineItems.clear();

      // 1. Fetch Call History
      final calls = await _dbService.getCallHistoryForLead(leadId);
      for (var call in calls) {
        _timelineItems.add(
          TimelineItem(date: call.callTime, type: 'call', data: call),
        );
      }

      // 2. Fetch Notes
      final notesMaps = await _dbService.getNotesForLead(leadId);
      for (var map in notesMaps) {
        _timelineItems.add(
          TimelineItem(
            date: DateTime.parse(map['createdAt']),
            type: 'note',
            data: map,
          ),
        );
      }

      // 3. Fetch Tasks (linked to this lead)
      // We'll access the provider's task list in the build method for the Tasks tab,
      // but for timeline, we might want to fetch directly or just use the provider if loaded.
      // For now, let's load tasks from DB for timeline to ensure accuracy.
      final allTasksMaps = await _dbService.getTasks();
      for (var map in allTasksMaps) {
        if (map['leadId'] == leadId) {
          _timelineItems.add(
            TimelineItem(
              date: DateTime.parse(map['dueDate']),
              type: 'task',
              data: Task.fromMap(map),
            ),
          );
        }
      }

      // 4. Fetch Communications
      final comms = await _dbService.getCommunicationsForLead(leadId);
      for (var comm in comms) {
        _timelineItems.add(
          TimelineItem(date: comm.timestamp, type: 'communication', data: comm),
        );
      }

      // Sort by date (newest first)
      _timelineItems.sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      debugPrint('Error loading timeline: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showEditLeadDialog() {
    final nameController = TextEditingController(text: _lead.name);
    final phoneController = TextEditingController(
      text: _lead.phoneNumber ?? '',
    );
    final emailController = TextEditingController(text: _lead.email ?? '');
    final descController = TextEditingController(text: _lead.description ?? '');

    // Handle legacy category values
    String selectedCategory = _lead.category;
    // Validate and get category from labels
    final labelService = Provider.of<LabelService>(context, listen: false);
    final validCategories = labelService.labels.map((l) => l.name).toList();
    if (validCategories.isEmpty) {
      validCategories.add('Client'); // Fallback default
    }
    if (!validCategories.contains(selectedCategory)) {
      // Map old values to new ones
      if (selectedCategory == 'jobs') {
        selectedCategory = 'Client';
      } else if (selectedCategory == 'internship' ||
          selectedCategory == 'paid_internship') {
        selectedCategory = 'Partner';
      } else {
        selectedCategory = 'Other'; // Default fallback
      }
    }

    // Handle legacy status values
    String selectedStatus = _lead.status;
    final validStatuses = [
      'New',
      'Contacted',
      'Qualified',
      'Converted',
      'Lost',
    ];
    if (!validStatuses.contains(selectedStatus)) {
      // Convert lowercase to capitalized
      selectedStatus =
          selectedStatus[0].toUpperCase() +
          selectedStatus.substring(1).toLowerCase();
      // If still not valid, default to 'New'
      if (!validStatuses.contains(selectedStatus)) {
        selectedStatus = 'New';
      }
    }

    // Track which fields are empty
    bool hasPhone = _lead.phoneNumber != null && _lead.phoneNumber!.isNotEmpty;
    bool hasEmail = _lead.email != null && _lead.email!.isNotEmpty;
    bool hasDescription =
        _lead.description != null && _lead.description!.isNotEmpty;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2A2A3E),
          title: Row(
            children: [
              const Text('Edit Lead', style: TextStyle(color: Colors.white)),
              const Spacer(),
              // Show indicator if fields are missing
              if (!hasPhone || !hasEmail || !hasDescription)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Incomplete',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show summary of missing fields
                  if (!hasPhone || !hasEmail || !hasDescription) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withAlpha(100)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.orange,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Missing Information',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (!hasPhone) _buildMissingFieldRow('Phone number'),
                          if (!hasEmail) _buildMissingFieldRow('Email address'),
                          if (!hasDescription)
                            _buildMissingFieldRow('Description'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      labelStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.person, color: Color(0xFF6C5CE7)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: Icon(
                        Icons.phone,
                        color: hasPhone
                            ? const Color(0xFF6C5CE7)
                            : Colors.orange,
                      ),
                      suffixIcon: !hasPhone
                          ? const Icon(
                              Icons.warning_amber,
                              color: Colors.orange,
                              size: 20,
                            )
                          : null,
                      helperText: !hasPhone ? 'Add phone number' : null,
                      helperStyle: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        hasPhone = value.trim().isNotEmpty;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: Icon(
                        Icons.email,
                        color: hasEmail
                            ? const Color(0xFF6C5CE7)
                            : Colors.orange,
                      ),
                      suffixIcon: !hasEmail
                          ? const Icon(
                              Icons.warning_amber,
                              color: Colors.orange,
                              size: 20,
                            )
                          : null,
                      helperText: !hasEmail ? 'Add email address' : null,
                      helperStyle: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        hasEmail = value.trim().isNotEmpty;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    dropdownColor: const Color(0xFF2A2A3E),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      labelStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(
                        Icons.category,
                        color: Color(0xFF6C5CE7),
                      ),
                    ),
                    items: Provider.of<LabelService>(context, listen: false)
                        .labels
                        .map((label) {
                          return DropdownMenuItem<String>(
                            value: label.name,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Color(
                                      int.parse(
                                        label.color.replaceFirst('#', '0xFF'),
                                      ),
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(label.name),
                              ],
                            ),
                          );
                        })
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedCategory = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    dropdownColor: const Color(0xFF2A2A3E),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Status *',
                      labelStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(
                        Icons.track_changes,
                        color: Color(0xFF6C5CE7),
                      ),
                    ),
                    items:
                        ['New', 'Contacted', 'Qualified', 'Converted', 'Lost']
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                    onChanged: (v) => setDialogState(() => selectedStatus = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: Icon(
                        Icons.description,
                        color: hasDescription
                            ? const Color(0xFF6C5CE7)
                            : Colors.orange,
                      ),
                      suffixIcon: !hasDescription
                          ? const Icon(
                              Icons.warning_amber,
                              color: Colors.orange,
                              size: 20,
                            )
                          : null,
                      helperText: !hasDescription ? 'Add a description' : null,
                      helperStyle: const TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                      ),
                      alignLabelWithHint: true,
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        hasDescription = value.trim().isNotEmpty;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
              ),
              onPressed: () async {
                final updatedLead = _lead.copyWith(
                  name: nameController.text.trim(),
                  phoneNumber: phoneController.text.trim(),
                  email: emailController.text.trim(),
                  category: selectedCategory,
                  status: selectedStatus,
                  description: descController.text.trim(),
                );
                await _dbService.updateLead(updatedLead);
                setState(() => _lead = updatedLead);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lead updated successfully'),
                    backgroundColor: Color(0xFF6C5CE7),
                  ),
                );
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingFieldRow(String fieldName) {
    return Padding(
      padding: const EdgeInsets.only(left: 26, top: 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: Colors.orange),
          const SizedBox(width: 8),
          Text(
            fieldName,
            style: const TextStyle(color: Colors.orange, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A2E),
          elevation: 0,
          title: Text(_lead.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showEditLeadDialog,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Color.fromARGB(229, 255, 255, 255),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
            tabs: [
              Tab(text: 'Info'),
              Tab(text: 'Timeline'),
              Tab(text: 'Tasks'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildHeader(), // Keep header always visible
            Expanded(
              child: TabBarView(
                children: [
                  _buildInfoTab(),
                  _buildTimelineTab(),
                  _buildTasksTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: _getCategoryColor(_lead.category).withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar with fixed size
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getCategoryColor(
                      _lead.category,
                    ).withAlpha((255 * 0.2).round()),
                    boxShadow: [
                      BoxShadow(
                        color: _getCategoryColor(
                          _lead.category,
                        ).withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _lead.name.isNotEmpty ? _lead.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: _getCategoryColor(_lead.category),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _lead.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_lead.isVip) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _makePhoneCall(_lead.phoneNumber),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.phone,
                              color: Color(0xFF6C5CE7),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _lead.phoneNumber ?? 'No phone number',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6C5CE7),
                                  decoration: TextDecoration.underline,
                                  height: 1.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(),
          const SizedBox(height: 24),
          _buildActionButtons(context),
          const SizedBox(height: 24),
          _buildNotesSection(),
        ],
      ),
    );
  }

  Widget _buildTimelineTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_timelineItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.withAlpha(100)),
            const SizedBox(height: 16),
            const Text('No activity yet', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _timelineItems.length,
      itemBuilder: (context, index) {
        final item = _timelineItems[index];
        return _buildTimelineItemWidget(item);
      },
    );
  }

  Widget _buildTimelineItemWidget(TimelineItem item) {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    switch (item.type) {
      case 'call':
        final call = item.data as CallHistory;
        icon = call.isIncoming ? Icons.call_received : Icons.call_made;
        color = call.isIncoming ? Colors.blue : Colors.green;
        title = call.isIncoming ? 'Incoming Call' : 'Outgoing Call';
        subtitle = '${call.duration}s • ${call.notes ?? "No notes"}';
        break;
      case 'task':
        final task = item.data as Task;
        icon = Icons.check_circle_outline;
        color = task.isCompleted ? Colors.green : Colors.orange;
        title = 'Task: ${task.title}';
        subtitle = task.description;
        break;
      case 'note':
        final note = item.data as Map<String, dynamic>;
        icon = Icons.note;
        color = Colors.amber;
        title = 'Note';
        subtitle = note['content'];
        break;
      case 'communication':
        final comm = item.data as Communication;
        final isAuto = comm.metadata?['automatic'] == 'true';
        final duration = _extractDuration(comm);
        icon = _getCommIcon(comm.type);
        color = _getCommColor(comm.type);
        title = '${comm.type.toUpperCase()} ${comm.direction}';
        // Show duration prominently, otherwise show body
        if (duration.isNotEmpty) {
          subtitle = '${isAuto ? "Auto-reply sent • " : ""}Duration: $duration';
        } else {
          subtitle = '${comm.body ?? ""}${isAuto ? " (Auto-reply)" : ""}';
        }
        break;
      default:
        icon = Icons.circle;
        color = Colors.grey;
        title = 'Unknown';
        subtitle = '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withAlpha(50),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    Container(
                      width: 2,
                      height: 40,
                      color: Colors.grey.withAlpha(50),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, h:mm a').format(item.date),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      if (item.type == 'communication')
                        _buildCommAction(item.data as Communication),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommAction(Communication comm) {
    final isAuto = comm.metadata?['automatic'] == 'true';
    if (!isAuto) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: ElevatedButton.icon(
        onPressed: () => _makePhoneCall(_lead.phoneNumber),
        icon: const Icon(Icons.call, size: 16),
        label: const Text('Call Back', style: TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C5CE7),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  IconData _getCommIcon(String type) {
    switch (type) {
      case 'call':
        return Icons.call;
      case 'sms':
        return Icons.sms;
      case 'email':
        return Icons.email;
      case 'whatsapp':
        return Icons.chat;
      default:
        return Icons.message;
    }
  }

  Color _getCommColor(String type) {
    switch (type) {
      case 'call':
        return Colors.green;
      case 'sms':
        return Colors.blue;
      case 'email':
        return Colors.orange;
      case 'whatsapp':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Widget _buildTasksTab() {
    return Consumer<TaskService>(
      builder: (context, taskService, child) {
        final tasks = taskService.tasks
            .where((t) => t.leadId == _lead.id)
            .toList();

        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'No tasks for this lead',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<TaskService>().addTaskForLead(_lead);
                    _loadData(); // Refresh timeline
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    foregroundColor: Colors.white, // Makes text and icon white
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Card(
              color: const Color(0xFF2A2A3E),
              child: ListTile(
                leading: Checkbox(
                  value: task.isCompleted,
                  onChanged: (val) {
                    final updated = task.copyWith(isCompleted: val!);
                    taskService.updateTask(updated);
                    _loadData(); // Refresh timeline
                  },
                  activeColor: const Color(0xFF6C5CE7),
                ),
                title: Text(
                  task.title,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  task.description,
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: Text(
                  DateFormat('MMM d').format(task.dueDate),
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _buildInfoRow(Icons.category, 'Category', _lead.category),
                _buildInfoRow(Icons.track_changes, 'Status', _lead.status),
                _buildClickableEmailRow(),
                _buildInfoRow(
                  Icons.call,
                  'Total Calls',
                  _lead.totalCalls.toString(),
                ),
                _buildInfoRow(
                  Icons.date_range,
                  'Last Call',
                  _lead.lastCallDate != null
                      ? DateFormat('MMM d, y').format(_lead.lastCallDate!)
                      : 'N/A',
                ),
                _buildInfoRow(
                  Icons.access_time,
                  'Assigned Time',
                  _lead.assignedTime ?? 'Not set',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClickableEmailRow() {
    final emailText = _lead.email ?? 'Not provided';
    final hasEmail = _lead.email != null && _lead.email!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.email,
                color: hasEmail ? const Color(0xFF6C5CE7) : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 16),
              const Text(
                'Email',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
          Flexible(
            child: GestureDetector(
              onTap: hasEmail ? () => _sendEmail(_lead.email) : null,
              child: Text(
                emailText,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  color: hasEmail ? const Color(0xFF6C5CE7) : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(context, Icons.call, 'Call'),
        _buildActionButton(context, Icons.message, 'Message'),
        _buildActionButton(context, Icons.email, 'Email'),
        _buildActionButton(context, Icons.event, 'Meeting'),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: const Color(0xFF6C5CE7),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 24),
            onPressed: () {
              if (label == 'Call') {
                _makePhoneCall(_lead.phoneNumber);
              } else if (label == 'Message') {
                _sendSMS(_lead.phoneNumber);
              } else if (label == 'Email') {
                _sendEmail(_lead.email);
              } else if (label == 'Meeting') {
                // Quick add task
                context.read<TaskService>().addTaskForLead(_lead);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Follow-up task added')),
                );
                _loadData();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label action not implemented yet')),
                );
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Notes & Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_comment, color: Color(0xFF6C5CE7)),
              onPressed: _showAddNoteDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A3E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _lead.description ?? 'No description provided.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  void _showAddNoteDialog() {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text('Add Note', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: noteController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter note...',
            hintStyle: TextStyle(color: Colors.grey),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white, // White text on purple
            ),
            onPressed: () async {
              if (noteController.text.isNotEmpty) {
                await _dbService.insertNote({
                  'content': noteController.text,
                  'createdAt': DateTime.now().toIso8601String(),
                  'leadId': _lead.id,
                });
                if (mounted) {
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  // Auto-refresh to show new note immediately
                  await _loadData();
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'jobs':
        return const Color(0xFF4ECDC4);
      case 'internship':
        return const Color(0xFFA29BFE);
      case 'paid_internship':
        return const Color(0xFF6C5CE7);
      default:
        return Colors.grey;
    }
  }

  // Click-to-call functionality
  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      _showSnackBar('No phone number available');
      return;
    }

    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar('Could not launch phone app');
    }
  }

  // Click-to-email functionality
  Future<void> _sendEmail(String? email) async {
    if (email == null || email.isEmpty) {
      _showSnackBar('No email address available');
      return;
    }

    try {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: email,
        query: 'subject=Hi ${_lead.name}',
      );
      await launchUrl(emailUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar('Could not launch email app');
    }
  }

  // SMS functionality
  Future<void> _sendSMS(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      _showSnackBar('No phone number available');
      return;
    }

    try {
      final Uri smsUri = Uri(scheme: 'sms', path: phoneNumber);
      await launchUrl(smsUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar('Could not launch SMS app');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  // Helper to extract duration from communication
  String _extractDuration(Communication comm) {
    // Check metadata first
    if (comm.metadata != null && comm.metadata!.containsKey('duration')) {
      final durationStr = comm.metadata!['duration'].toString();
      final seconds =
          int.tryParse(durationStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (seconds > 0) return _formatDuration(seconds);
    }

    // Try to parse from body (e.g., "Duration: 45s")
    if (comm.body != null && comm.body!.contains('Duration:')) {
      final match = RegExp(r'Duration:\s*(\d+)s').firstMatch(comm.body!);
      if (match != null) {
        final seconds = int.tryParse(match.group(1)!) ?? 0;
        return _formatDuration(seconds);
      }
    }

    return '';
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return '';
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (secs == 0) return '${minutes}m';
    return '${minutes}m ${secs}s';
  }
}

class TimelineItem {
  final DateTime date;
  final String type; // 'call', 'note', 'task'
  final dynamic data;

  TimelineItem({required this.date, required this.type, required this.data});
}
