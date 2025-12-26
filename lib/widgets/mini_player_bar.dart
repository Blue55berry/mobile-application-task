import 'package:flutter/material.dart';
import '../services/audio_guide_service.dart';

/// Modern Mini Player Bar - Spotify/YouTube style
class MiniPlayerBar extends StatefulWidget {
  const MiniPlayerBar({super.key});

  @override
  State<MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends State<MiniPlayerBar>
    with SingleTickerProviderStateMixin {
  final AudioGuideService _audioService = AudioGuideService();
  late AnimationController _expandController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _audioService.init();
    _audioService.addListener(_onAudioChange);

    _expandController = AnimationController(
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
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _skipForward() {
    final newPosition = _audioService.position + const Duration(seconds: 10);
    if (newPosition < _audioService.duration) {
      _audioService.seek(newPosition);
    }
  }

  void _skipBackward() {
    final newPosition = _audioService.position - const Duration(seconds: 10);
    if (newPosition > Duration.zero) {
      _audioService.seek(newPosition);
    } else {
      _audioService.seek(Duration.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show start button if not playing or paused
    if (!_audioService.isPlaying && !_audioService.isPaused) {
      return _buildStartButton();
    }

    return GestureDetector(
      onTap: _toggleExpand,
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! > 0) {
          // Swipe down - minimize
          if (_isExpanded) {
            setState(() {
              _isExpanded = false;
              _expandController.reverse();
            });
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _isExpanded ? 280 : 70,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF2A2A3E), const Color(0xFF1A1A2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _isExpanded ? _buildExpandedPlayer() : _buildMiniPlayer(),
      ),
    );
  }

  Widget _buildStartButton() {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFFA855F7)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => _audioService.playAppOverview(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.headphones, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Listen to App Guide',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniPlayer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Play/Pause Button
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFFA855F7)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                _audioService.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () => _audioService.togglePlayPause(),
            ),
          ),
          const SizedBox(width: 12),

          // Title and Progress
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'App Guide Audio',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _audioService.progress,
                        backgroundColor: Colors.grey[800],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF6C5CE7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(_audioService.position),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Stop button
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: () {
              _audioService.stop();
              setState(() {
                _isExpanded = false;
                _expandController.reverse();
              });
            },
            tooltip: 'Stop & Close',
          ),

          // Expand icon
          Icon(Icons.keyboard_arrow_up, color: Colors.grey[400], size: 20),
        ],
      ),
    );
  }

  Widget _buildExpandedPlayer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 8),

          // Title
          const Text(
            'App Guide Audio',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tutorial overview',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          const SizedBox(height: 12),

          // Progress slider - more compact
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF6C5CE7),
              inactiveTrackColor: Colors.grey[800],
              thumbColor: const Color(0xFF6C5CE7),
              overlayColor: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              trackHeight: 2,
            ),
            child: Slider(
              value: _audioService.position.inMilliseconds.toDouble(),
              min: 0,
              max: _audioService.duration.inMilliseconds.toDouble(),
              onChanged: (value) {
                _audioService.seek(Duration(milliseconds: value.toInt()));
              },
            ),
          ),

          // Time labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_audioService.position),
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                Text(
                  _formatDuration(_audioService.duration),
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Skip backward
              IconButton(
                icon: const Icon(
                  Icons.replay_10,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _skipBackward,
              ),

              // Play/Pause
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFFA855F7)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    _audioService.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => _audioService.togglePlayPause(),
                ),
              ),

              // Skip forward
              IconButton(
                icon: const Icon(
                  Icons.forward_10,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _skipForward,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
