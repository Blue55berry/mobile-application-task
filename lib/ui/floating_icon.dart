import 'package:flutter/material.dart';

/// FloatingIconWidget
///
/// Circular floating icon that appears during active calls.
/// Features:
/// - SBS branding
/// - Draggable
/// - Positioned at screen edge
/// - Tap to expand popup
class FloatingIconWidget extends StatefulWidget {
  final VoidCallback onTap;

  const FloatingIconWidget({super.key, required this.onTap});

  @override
  State<FloatingIconWidget> createState() => _FloatingIconWidgetState();
}

class _FloatingIconWidgetState extends State<FloatingIconWidget> {
  // Position of the floating icon
  Offset position = const Offset(20, 100);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Draggable(
        feedback: _buildIcon(isDragging: true),
        childWhenDragging: const SizedBox.shrink(),
        onDragEnd: (details) {
          setState(() {
            // Keep icon within screen bounds
            final screenSize = MediaQuery.of(context).size;
            double newX = details.offset.dx;
            double newY = details.offset.dy;

            // Clamp to screen bounds
            newX = newX.clamp(0, screenSize.width - 60);
            newY = newY.clamp(0, screenSize.height - 60);

            position = Offset(newX, newY);
          });
        },
        child: GestureDetector(onTap: widget.onTap, child: _buildIcon()),
      ),
    );
  }

  Widget _buildIcon({bool isDragging = false}) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF5B4CD3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
            blurRadius: isDragging ? 20 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'SBS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.3),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
