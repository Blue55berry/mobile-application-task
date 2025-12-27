import 'package:flutter/material.dart';
import '../models/lead_model.dart';
import '../services/database_service.dart';

class CallDetailsPopup extends StatefulWidget {
  final Lead lead;
  final VoidCallback onClose;

  const CallDetailsPopup({
    super.key,
    required this.lead,
    required this.onClose,
  });

  @override
  State<CallDetailsPopup> createState() => _CallDetailsPopupState();
}

class _CallDetailsPopupState extends State<CallDetailsPopup>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _noteController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  int _noteLength = 0;
  String? _photoUrl;
  final bool _isFetchingPhoto = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _noteController.addListener(() {
      setState(() {
        _noteLength = _noteController.text.length;
      });
    });
    // Photo fetching removed - using local contact photos from database
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A3E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                _buildActionButtons(),
                _buildTabs(),
                Flexible(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActionTab(),
                      _buildActivityTab(),
                      _buildInsightTab(),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Avatar and user info
          Row(
            children: [
              Stack(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF6C5CE7),
                        backgroundImage: _photoUrl != null
                            ? NetworkImage(_photoUrl!)
                            : null,
                        child: _photoUrl == null && !_isFetchingPhoto
                            ? Text(
                                widget.lead.name.isNotEmpty
                                    ? widget.lead.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      if (_isFetchingPhoto)
                        const SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (widget.lead.isVip)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFD700),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.lead.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.lead.isVip) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'VIP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.lead.phoneNumber ?? 'No phone',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                _saveNote();
              },
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                _showCreateTaskDialog();
              },
              icon: const Icon(Icons.task_alt, size: 18),
              label: const Text('Task'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.grey),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateTaskDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Task creation feature coming soon!')),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF6C5CE7),
        labelColor: const Color(0xFF6C5CE7),
        unselectedLabelColor: Colors.grey,
        tabs: const [
          Tab(text: 'Action'),
          Tab(text: 'Activity'),
          Tab(text: 'Insight'),
        ],
      ),
    );
  }

  Widget _buildActionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _noteController,
            maxLines: 8,
            maxLength: 160,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Add a note about this call...',
              hintStyle: TextStyle(color: Colors.grey),
              border: InputBorder.none,
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildBottomActionIcon(Icons.label_outline, 'Labels'),
                  const SizedBox(width: 16),
                  _buildBottomActionIcon(Icons.note_outlined, 'Note'),
                  const SizedBox(width: 16),
                  _buildBottomActionIcon(Icons.alarm, 'Reminder'),
                  const SizedBox(width: 16),
                  _buildBottomActionIcon(Icons.task_alt, 'Task'),
                ],
              ),
              Text(
                '$_noteLength/160',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await _saveNote();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Save Note',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'Call Activity',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total Calls: ${widget.lead.totalCalls ?? 0}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          if (widget.lead.lastCallDate != null) ...[
            const SizedBox(height: 4),
            Text(
              'Last Call: ${_formatDate(widget.lead.lastCallDate!)}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lightbulb_outline, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'Insights',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Category: ${_getCategoryLabel(widget.lead.category)}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Status: ${widget.lead.status}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionIcon(IconData icon, String label) {
    return InkWell(
      onTap: () {
        // Handle action icon tap
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$label action (coming soon)')));
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF6C5CE7), size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'jobs':
        return 'Job';
      case 'internship':
        return 'Internship';
      case 'paid_internship':
        return 'Paid Internship';
      default:
        return category;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _saveNote() async {
    if (_noteController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a note')));
      return;
    }

    // Update lead description with the note
    final updatedLead = widget.lead.copyWith(description: _noteController.text);

    await _dbService.updateLead(updatedLead);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note saved successfully'),
        backgroundColor: Color(0xFF6C5CE7),
      ),
    );

    _noteController.clear();
  }
}
