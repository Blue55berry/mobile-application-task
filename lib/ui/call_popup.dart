import 'package:flutter/material.dart';
import '../models/lead_model.dart';

class CallPopupWidget extends StatefulWidget {
  final Lead? lead;
  final String phoneNumber;
  final bool isIncoming;
  final VoidCallback onClose;

  const CallPopupWidget({
    super.key,
    this.lead,
    required this.phoneNumber,
    required this.isIncoming,
    required this.onClose,
  });

  @override
  State<CallPopupWidget> createState() => _CallPopupWidgetState();
}

class _CallPopupWidgetState extends State<CallPopupWidget> {
  int _selectedTabIndex = 0;
  final TextEditingController _noteController = TextEditingController();
  int _noteLength = 0;

  @override
  void initState() {
    super.initState();
    _noteController.addListener(() {
      setState(() {
        _noteLength = _noteController.text.length;
      });
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2A2A3E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            if (widget.lead != null) _buildActionButtons(),
            _buildTabs(),
            SizedBox(height: 200, child: _buildTabContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final String name = widget.lead?.name ?? 'Unknown Caller';
    final String displayNumber = widget.phoneNumber;
    final bool isVip = widget.lead?.isVip ?? false;

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
          const SizedBox(height: 16),

          // Call direction indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isIncoming
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.isIncoming ? '📞 Incoming Call' : '📱 Outgoing Call',
              style: TextStyle(
                color: widget.isIncoming ? Colors.green : Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Avatar and user info
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF6C5CE7),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isVip)
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
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayNumber,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    if (widget.lead != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${widget.lead!.status}',
                        style: const TextStyle(
                          color: Color(0xFF6C5CE7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: widget.onClose,
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
            child: OutlinedButton.icon(
              onPressed: () {
                // Move to action
              },
              icon: const Icon(Icons.drive_file_move, size: 18),
              label: const Text('Move'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.grey),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                // Create meeting
              },
              icon: const Icon(Icons.event, size: 18),
              label: const Text('Meeting'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.grey),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          _buildTab('Action', 0),
          _buildTab('Activity', 1),
          _buildTab('Insight', 2),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? const Color(0xFF6C5CE7)
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? const Color(0xFF6C5CE7) : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildActionTab();
      case 1:
        return _buildActivityTab();
      case 2:
        return _buildInsightTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _noteController,
            maxLines: 3,
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
                  _buildBottomActionIcon(Icons.note_outlined, 'Note'),
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
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 48, color: Colors.grey[600]),
          const SizedBox(height: 12),
          Text(
            widget.lead != null
                ? 'Total Calls: ${widget.lead!.totalCalls ?? 0}'
                : 'No activity history',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lightbulb_outline, size: 48, color: Colors.grey[600]),
          const SizedBox(height: 12),
          Text(
            widget.lead != null
                ? 'Category: ${widget.lead!.category}'
                : 'New contact',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionIcon(IconData icon, String label) {
    return InkWell(
      onTap: () {
        // Handle action
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
}
