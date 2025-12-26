import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// AudioGuideService - Manages app tutorial audio playback
class AudioGuideService extends ChangeNotifier {
  static final AudioGuideService _instance = AudioGuideService._internal();
  factory AudioGuideService() => _instance;
  AudioGuideService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isPaused = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  Duration get duration => _duration;
  Duration get position => _position;
  double get progress => _duration.inMilliseconds > 0
      ? _position.inMilliseconds / _duration.inMilliseconds
      : 0.0;

  /// Initialize the audio player
  Future<void> init() async {
    _audioPlayer.onDurationChanged.listen((duration) {
      _duration = duration;
      notifyListeners();
    });

    _audioPlayer.onPositionChanged.listen((position) {
      _position = position;
      notifyListeners();
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _isPaused = false;
      _position = Duration.zero;
      notifyListeners();
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      _isPaused = state == PlayerState.paused;
      notifyListeners();
    });
  }

  /// Play the app overview audio
  Future<void> playAppOverview() async {
    try {
      await _audioPlayer.play(AssetSource('audio/app_overview.mp3'));
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  /// Pause playback
  Future<void> pause() async {
    await _audioPlayer.pause();
    _isPaused = true;
    _isPlaying = false;
    notifyListeners();
  }

  /// Resume playback
  Future<void> resume() async {
    await _audioPlayer.resume();
    _isPlaying = true;
    _isPaused = false;
    notifyListeners();
  }

  /// Stop playback
  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    _isPaused = false;
    _position = Duration.zero;
    notifyListeners();
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else if (_isPaused) {
      await resume();
    } else {
      await playAppOverview();
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
