import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

void main() {
  runApp(const OverlayWidget());
}

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  Map<String, dynamic> _leadData = {};
  bool _isSaved = false;
  int _selectedTabIndex = 0;
  int _callDurationSeconds = 0;
  Timer? _callTimer;
  bool _isCallConnected = false;

  @override
  void initState() {
    super.initState();
    _listenToData();
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    setState(() {
      _callDurationSeconds = 0;
      _isCallConnected = true;
    });

    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDurationSeconds++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _formatCallDuration() {
    if (!_isCallConnected) {
      return 'Connecting...';
    }
    final minutes = (_callDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_callDurationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _listenToData() {
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (mounted) {
        if (data is Map) {
          final eventData = Map<String, dynamic>.from(data);
          if (eventData['event'] == 'call_started') {
            _startCallTimer();
          } else {
            setState(() {
              _leadData = eventData;
              _isSaved = _leadData['isSaved'] ?? false;
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: _isSaved ? _buildSavedContactOverlay() : _buildNewLeadOverlay(),
      ),
    );
  }

  Widget _buildSavedContactOverlay() {
    final String name = _leadData['name'] ?? 'Unknown';
    final String phone = _leadData['phoneNumber'] ?? '';
    final String category = _leadData['category'] ?? 'Client';
    final bool isVip = _leadData['isVip'] ?? false;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timer Display
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _formatCallDuration(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                  letterSpacing: 2,
                ),
              ),
            ),

            // Profile Image with Phone Badge
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade300, Colors.blue.shade300],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6C5CE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.phone,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Contact Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _leadData['description'] ?? 'Lead',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tags
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildTag(category, Colors.orange),
                  if (isVip) _buildTag('VIP', Colors.amber),
                  _buildTag('+2 others', const Color(0xFF6C5CE7)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Tab Navigation
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.black12, width: 1),
                ),
              ),
              child: Row(
                children: [
                  _buildTab('Action', 0),
                  _buildTab('Activity', 1),
                  _buildTab('Insight', 2),
                ],
              ),
            ),

            // Content Area
            Container(
              height: 120,
              padding: const EdgeInsets.all(20),
              child: _buildTabContent(),
            ),

            // Bottom Action Buttons
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.black12, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBottomAction(Icons.label_outline, 'Tags'),
                  _buildBottomAction(Icons.note_outlined, 'Note'),
                  _buildBottomAction(Icons.alarm, 'Reminder', isActive: true),
                  _buildBottomAction(Icons.check_circle_outline, 'Task'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: 0.9),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
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
          padding: const EdgeInsets.symmetric(vertical: 14),
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
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? const Color(0xFF6C5CE7) : Colors.black45,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0: // Action
        return const Center(
          child: Text(
            'Jenkins House Showing 11:30',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
        );
      case 1: // Activity
        return const Center(
          child: Text(
            'Recent activity will appear here',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
        );
      case 2: // Insight
        return const Center(
          child: Text(
            'Lead insights and analytics',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomAction(
    IconData icon,
    String label, {
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: () {
        FlutterOverlayWindow.shareData({
          'action': label.toLowerCase(),
          'phone': _leadData['phoneNumber'],
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF6C5CE7) : Colors.black54,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? const Color(0xFF6C5CE7) : Colors.black54,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewLeadOverlay() {
    final String phone = _leadData['phoneNumber'] ?? 'Unknown';

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timer
            Text(
              _formatCallDuration(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            // Unknown caller icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade300,
              ),
              child: const Icon(
                Icons.person_outline,
                size: 40,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Unknown Caller',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              phone,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  FlutterOverlayWindow.shareData({
                    'action': 'save_new_lead',
                    'phone': phone,
                  });
                },
                icon: const Icon(Icons.person_add),
                label: const Text(
                  'Save as New Lead',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
