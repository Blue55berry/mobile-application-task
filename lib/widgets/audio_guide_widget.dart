import 'package:flutter/material.dart';
import '../services/audio_guide_service.dart';

/// Floating Audio Guide Button - shows a floating button to play app tutorial
class FloatingAudioGuide extends StatefulWidget {
  const FloatingAudioGuide({super.key});

  @override
  State<FloatingAudioGuide> createState() => _FloatingAudioGuideState();
}

class _FloatingAudioGuideState extends State<FloatingAudioGuide>
    with SingleTickerProviderStateMixin {
  final AudioGuideService _audioService = AudioGuideService();
  late AnimationController _animationController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _audioService.init();
    _audioService.addListener(_onAudioChange);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _onAudioChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioChange);
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Expanded player controls
          if (_isExpanded || _audioService.isPlaying || _audioService.isPaused)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A3E),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Title
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.headphones,
                        color: Color(0xFF6C5CE7),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'App Guide',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Progress bar
                  if (_audioService.isPlaying || _audioService.isPaused)
                    Column(
                      children: [
                        SizedBox(
                          width: 150,
                          child: LinearProgressIndicator(
                            value: _audioService.progress,
                            backgroundColor: Colors.grey[800],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF6C5CE7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatDuration(_audioService.position)} / ${_formatDuration(_audioService.duration)}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 8),

                  // Control buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Play/Pause button
                      IconButton(
                        onPressed: () => _audioService.togglePlayPause(),
                        icon: Icon(
                          _audioService.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          color: const Color(0xFF6C5CE7),
                          size: 40,
                        ),
                      ),

                      // Stop button
                      if (_audioService.isPlaying || _audioService.isPaused)
                        IconButton(
                          onPressed: () => _audioService.stop(),
                          icon: const Icon(
                            Icons.stop_circle,
                            color: Colors.grey,
                            size: 32,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

          // Main floating button
          GestureDetector(
            onTap: _toggleExpand,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFFA855F7)],
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
              child: Icon(
                _audioService.isPlaying ? Icons.volume_up : Icons.headphones,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple Audio Guide Button - for adding to app bar or settings
class AudioGuideButton extends StatefulWidget {
  const AudioGuideButton({super.key});

  @override
  State<AudioGuideButton> createState() => _AudioGuideButtonState();
}

class _AudioGuideButtonState extends State<AudioGuideButton> {
  final AudioGuideService _audioService = AudioGuideService();

  @override
  void initState() {
    super.initState();
    _audioService.init();
    _audioService.addListener(_onAudioChange);
  }

  void _onAudioChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _audioService.togglePlayPause(),
      icon: Icon(
        _audioService.isPlaying ? Icons.pause : Icons.headphones,
        color: const Color(0xFF6C5CE7),
      ),
      tooltip: _audioService.isPlaying ? 'Pause Guide' : 'Listen to Guide',
    );
  }
}
