import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/lead_model.dart';
import 'services/database_service.dart';
import 'ui/call_popup.dart';
import 'ui/floating_icon.dart';

/// Overlay Entry Point
///
/// This is the entry point for the system overlay that appears during calls.
/// It's launched by the Android native CallOverlayService via FlutterEngine.
///
/// Features:
/// - Displays CRM data for saved contacts
/// - Shows "Unknown Caller" for unsaved numbers
/// - Floating SBS icon
/// - Call timer
void main() {
  runApp(const CallOverlayApp());
}

class CallOverlayApp extends StatelessWidget {
  const CallOverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const CallOverlayScreen(),
      theme: ThemeData.dark(),
    );
  }
}

class CallOverlayScreen extends StatefulWidget {
  const CallOverlayScreen({super.key});

  @override
  State<CallOverlayScreen> createState() => _CallOverlayScreenState();
}

class _CallOverlayScreenState extends State<CallOverlayScreen> {
  static const platform = MethodChannel('com.example.sbs/call_overlay');

  final DatabaseService _dbService = DatabaseService();

  // Call state
  String? _phoneNumber;
  Lead? _lead;
  bool _isIncoming = true;
  bool _showPopup = false;
  bool _showFloatingIcon = false;

  // Call timer
  int _callDurationSeconds = 0;
  Timer? _callTimer;
  bool _isCallActive = false;

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  /// Setup MethodChannel to receive events from Android
  void _setupMethodChannel() {
    platform.setMethodCallHandler((call) async {
      debugPrint('📱 Overlay received method call: ${call.method}');

      switch (call.method) {
        case 'onCallReceived':
          await _handleCallReceived(call.arguments as Map);
          break;

        case 'onCallStarted':
          _handleCallStarted(call.arguments as Map);
          break;

        case 'onHideOverlay':
          _handleHideOverlay();
          break;

        default:
          debugPrint('⚠️ Unknown method: ${call.method}');
      }
    });

    debugPrint('✅ MethodChannel listener setup complete');
  }

  /// Handle incoming/outgoing call event from Android
  Future<void> _handleCallReceived(Map arguments) async {
    final phoneNumber = arguments['phoneNumber'] as String?;
    final isIncoming = arguments['isIncoming'] as bool? ?? true;

    debugPrint('📞 Call received: $phoneNumber (Incoming: $isIncoming)');

    if (phoneNumber == null) return;

    setState(() {
      _phoneNumber = phoneNumber;
      _isIncoming = isIncoming;
      _showFloatingIcon = true;
    });

    // Query CRM database for lead
    try {
      final lead = await _dbService.getLeadByPhone(phoneNumber);

      setState(() {
        _lead = lead;
        _showPopup = true; // Auto-show popup when call received
      });

      debugPrint('✅ Lead found: ${lead?.name ?? "NONE"}');
    } catch (e) {
      debugPrint('❌ Error querying lead: $e');
    }
  }

  /// Handle call started (connected) event
  void _handleCallStarted(Map arguments) {
    debugPrint('📞 Call started');

    setState(() {
      _isCallActive = true;
      _callDurationSeconds = 0;
    });

    _startCallTimer();
  }

  /// Handle hide overlay event
  void _handleHideOverlay() {
    debugPrint('📞 Hiding overlay');

    setState(() {
      _showPopup = false;
      _showFloatingIcon = false;
      _isCallActive = false;
      _phoneNumber = null;
      _lead = null;
    });

    _callTimer?.cancel();
  }

  /// Start call duration timer
  void _startCallTimer() {
    _callTimer?.cancel();

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

  /// Format call duration as MM:SS
  String _formatCallDuration() {
    if (!_isCallActive) {
      return 'Connecting...';
    }
    final minutes = (_callDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_callDurationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Floating Icon
          if (_showFloatingIcon && !_showPopup)
            FloatingIconWidget(
              onTap: () {
                setState(() {
                  _showPopup = true;
                });
              },
            ),

          // Full Popup
          if (_showPopup && _phoneNumber != null)
            GestureDetector(
              onTap: () {
                setState(() {
                  _showPopup = false;
                });
              },
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: GestureDetector(
                  onTap: () {}, // Prevent dismissal when tapping popup
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Call timer
                        if (_isCallActive)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A3E),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              _formatCallDuration(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 2,
                              ),
                            ),
                          ),

                        // Popup
                        CallPopupWidget(
                          lead: _lead,
                          phoneNumber: _phoneNumber!,
                          isIncoming: _isIncoming,
                          onClose: () {
                            setState(() {
                              _showPopup = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
