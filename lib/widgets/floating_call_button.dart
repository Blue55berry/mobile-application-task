import 'package:flutter/material.dart';

class FloatingCallButton extends StatefulWidget {
  final VoidCallback onTap;

  const FloatingCallButton({super.key, required this.onTap});

  @override
  State<FloatingCallButton> createState() => _FloatingCallButtonState();
}

class _FloatingCallButtonState extends State<FloatingCallButton> {
  Offset _position = const Offset(20, 100);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Draggable(
        feedback: _buildButton(),
        childWhenDragging: Container(),
        onDragEnd: (details) {
          setState(() {
            // Keep button within screen bounds
            double newX = details.offset.dx.clamp(0.0, size.width - 60);
            double newY = details.offset.dy.clamp(0.0, size.height - 60);
            _position = Offset(newX, newY);
          });
        },
        child: GestureDetector(onTap: widget.onTap, child: _buildButton()),
      ),
    );
  }

  Widget _buildButton() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'SBS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
