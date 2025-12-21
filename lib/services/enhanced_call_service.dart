// lib/services/enhanced_call_service.dart (updated)

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:phone_state/phone_state.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../models/call_model.dart';
import '../models/lead_model.dart';
import '../models/call_history_model.dart';
import 'database_service.dart';
import 'call_overlay_service.dart';

import '../main.dart';

class EnhancedCallService extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  CallOverlayService? _overlayService;
  // ... (rest of the properties are the same)
  CallModel? _currentCall;
  Lead? _callerLead;
  bool _hasIncomingCall = false;
  bool _isCallActive = false;
  DateTime? _callStartTime;
  int _callDuration = 0;

  // Getters
  CallModel? get currentCall => _currentCall;
  Lead? get callerLead => _callerLead;
  bool get hasIncomingCall => _hasIncomingCall;
  bool get isCallActive => _isCallActive;
  int get callDuration => _callDuration;

  EnhancedCallService() {
    _initPhoneStateListener();
    _initOverlayListener();
  }

  void setOverlayService(CallOverlayService overlayService) {
    _overlayService = overlayService;
  }

  void _initOverlayListener() {
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map) {
        final action = data['action'] as String?;
        if (action == 'show_details') {
          final phone = data['phone'] as String?;
          if (phone != null) _handleShowDetails(phone);
        } else if (action == 'save_new_lead_from_overlay') {
          _handleSaveLeadFromOverlay(data);
        } else if (action == 'add_note_from_overlay') {
          _handleAddNoteFromOverlay(data);
        } else if (action == 'create_task') {
          _handleCreateTask(data);
        } else if (action == 'create_meeting') {
          _handleCreateMeeting(data);
        } else if (action == 'set_reminder') {
          _handleSetReminder(data);
        } else if (action == 'add_label') {
          _handleAddLabel(data);
        } else if (action == 'move_to_stage') {
          _handleMoveToStage(data);
        }
      }
    });
  }

  // Handler for creating task from overlay
  Future<void> _handleCreateTask(Map<dynamic, dynamic> data) async {
    final phone = data['phone'] as String?;
    if (phone == null) return;

    final lead = await _dbService.getLeadByPhone(phone);
    if (lead != null && lead.id != null) {
      debugPrint('📋 Creating task for ${lead.name}');
      // Task creation would be handled by TaskService
      notifyListeners();
    }
  }

  // Handler for creating meeting
  Future<void> _handleCreateMeeting(Map<dynamic, dynamic> data) async {
    final phone = data['phone'] as String?;
    if (phone == null) return;

    final lead = await _dbService.getLeadByPhone(phone);
    if (lead != null && lead.id != null) {
      debugPrint('📅 Creating meeting for ${lead.name}');
      // Meeting creation logic here
      notifyListeners();
    }
  }

  // Handler for setting reminder
  Future<void> _handleSetReminder(Map<dynamic, dynamic> data) async {
    final phone = data['phone'] as String?;
    if (phone == null) return;

    final lead = await _dbService.getLeadByPhone(phone);
    if (lead != null && lead.id != null) {
      debugPrint('⏰ Setting reminder for ${lead.name}');
      // Reminder logic here
      notifyListeners();
    }
  }

  // Handler for adding label
  Future<void> _handleAddLabel(Map<dynamic, dynamic> data) async {
    final phone = data['phone'] as String?;
    if (phone == null) return;

    final lead = await _dbService.getLeadByPhone(phone);
    if (lead != null && lead.id != null) {
      debugPrint('🏷️ Adding label for ${lead.name}');
      // Label logic here
      notifyListeners();
    }
  }

  // Handler for moving to stage
  Future<void> _handleMoveToStage(Map<dynamic, dynamic> data) async {
    final phone = data['phone'] as String?;
    if (phone == null) return;

    final lead = await _dbService.getLeadByPhone(phone);
    if (lead != null && lead.id != null) {
      debugPrint('📊 Moving ${lead.name} to new stage');
      // Stage movement logic here
      notifyListeners();
    }
  }

  Future<void> _handleAddNoteFromOverlay(Map<dynamic, dynamic> data) async {
    try {
      final phone = data['phone'] as String?;
      final noteContent = data['note'] as String?;

      if (phone != null && noteContent != null) {
        final lead = await _dbService.getLeadByPhone(phone);
        if (lead != null && lead.id != null) {
          await _dbService.insertNote({
            'leadId': lead.id,
            'content': noteContent,
            'createdAt': DateTime.now().toIso8601String(),
          });
          debugPrint('✅ Note added from overlay for ${lead.name}');

          // Optionally refresh or notify
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ Error adding note from overlay: $e');
    }
  }

  Future<void> _handleSaveLeadFromOverlay(Map<dynamic, dynamic> data) async {
    try {
      final lead = Lead(
        name: data['name'] as String,
        category: data['category'] as String,
        status: data['status'] as String,
        createdAt: DateTime.now(),
        phoneNumber: data['phone'] as String?,
        email: data['email'] as String?,
        description: data['description'] as String?,
        isVip: data['isVip'] as bool? ?? false,
      );

      final newId = await _dbService.insertLead(lead);
      _callerLead = lead.copyWith(id: newId);
      debugPrint('✅ Lead saved from overlay with ID: $newId');

      // Notify listeners in the main app (e.g., to refresh leads list)
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error saving lead from overlay: $e');
    }
  }

  Future<void> _handleShowDetails(String phoneNumber) async {
    try {
      debugPrint('🔍 _handleShowDetails called for: $phoneNumber');
      final lead = await _dbService.getLeadByPhone(phoneNumber);
      final navigator = navigatorKey.currentState;

      if (lead != null && navigator != null) {
        debugPrint('✅ Lead found: ${lead.name}. Navigating to details screen.');

        // Navigate to the LeadDetailScreen
        navigator.pushNamed('/lead_details', arguments: lead);

        debugPrint('✅ Navigation to details screen requested.');
      } else {
        debugPrint('❌ Lead not found or navigator state is null');
      }
    } catch (e) {
      debugPrint('❌ Error showing lead details: $e');
    }
  }

  // ... (rest of the service is the same)
  void _initPhoneStateListener() {
    PhoneState.stream.listen((event) async {
      switch (event.status) {
        case PhoneStateStatus.CALL_INCOMING:
          await _handleIncomingCall(event.number ?? 'Unknown');
          break;
        case PhoneStateStatus.CALL_STARTED:
          _handleCallStarted();
          break;
        case PhoneStateStatus.CALL_ENDED:
          await _handleCallEnded();
          break;
        case PhoneStateStatus.NOTHING:
          break;
        case PhoneStateStatus.CALL_OUTGOING:
          await _handleOutgoingCall(event.number ?? 'Unknown');
          break;
      }
    });
  }

  Future<void> _handleIncomingCall(String phoneNumber) async {
    debugPrint('📞 INCOMING CALL from: $phoneNumber');

    final existingLead = await _dbService.getLeadByPhone(phoneNumber);

    debugPrint('🔍 Lead lookup result: ${existingLead?.name ?? "NOT FOUND"}');

    _currentCall = CallModel(
      phoneNumber: phoneNumber,
      callerName: existingLead?.name,
      callTime: DateTime.now(),
      isIncoming: true,
    );

    _callerLead = existingLead;
    _hasIncomingCall = true;

    // Show system-wide overlay for both saved and unsaved users
    if (_callerLead != null) {
      debugPrint('✅ Saved lead found! Showing overlays...');

      // Show in-app floating icon for saved users
      if (_overlayService != null) {
        debugPrint('📱 Showing in-app floating icon');
        _overlayService!.showFloatingIcon(_callerLead!);
      }

      // Show system-wide overlay: DELEGATED TO BACKGROUND SERVICE
      // We no longer call _showSystemOverlay here to avoid duplicates.
      // The Background Service listens to PhoneState independently.
    } else {
      debugPrint(
        '❌ No lead found for this number - showing overlay with phone only',
      );
      // Background Service handles this too.
    }

    notifyListeners();
  }

  Future<void> _showSystemOverlay(Lead? lead) async {
    debugPrint(
      '🎯 _showSystemOverlay called for: ${lead?.name ?? "UNKNOWN CALLER"}',
    );

    try {
      // Check if overlay permission is granted
      debugPrint('🔐 Checking overlay permission...');
      final status = await FlutterOverlayWindow.isPermissionGranted();
      debugPrint('🔐 Permission status: $status');

      if (!status) {
        debugPrint('⚠️ Permission NOT granted - requesting now...');
        // Request permission (opens settings)
        final requested = await FlutterOverlayWindow.requestPermission();
        debugPrint('📋 Permission request result: $requested');
        return;
      }

      debugPrint('✅ Permission granted! Showing overlay...');

      // Choose overlay style based on whether the user is known
      // Choose overlay style based on whether the user is known
      if (lead != null) {
        // SAVED USER: Show a compact, draggable card
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          overlayTitle: "SBS Caller ID",
          overlayContent: "Contact: ${lead.name}",
          flag: OverlayFlag.defaultFlag, // Makes it interactive (buttons work)
          visibility: NotificationVisibility.visibilityPublic,
          positionGravity: PositionGravity.auto,
          height: 280, // Height for the card with buttons
          width: WindowSize.matchParent,
        );
      } else {
        // UNKNOWN USER: Show small floating pill (previously full screen)
        await FlutterOverlayWindow.showOverlay(
          enableDrag: true,
          overlayTitle: "SBS Caller ID",
          overlayContent: "Unknown Caller",
          flag: OverlayFlag.defaultFlag,
          visibility: NotificationVisibility.visibilityPublic,
          positionGravity: PositionGravity.auto,
          height: 120, // Small height for the pill
          width: WindowSize.matchParent,
        );
      }

      debugPrint('📤 Overlay shown! Sending data...');

      // Send caller data to overlay
      if (lead != null) {
        // Saved user - send FULL details including call time
        debugPrint('📊 Sending FULL user data: ${lead.name}');
        await FlutterOverlayWindow.shareData({
          'name': lead.name,
          'phone': lead.phoneNumber ?? '',
          'email': lead.email ?? '',
          'category': lead.category,
          'status': lead.status,
          'isVip': lead.isVip,
          'description': lead.description ?? '',
          'totalCalls': lead.totalCalls ?? 0,
          'lastCallTime': lead.lastCallDate?.toIso8601String(),
          'callTime': DateTime.now().toIso8601String(),
          'isSaved': true,
        });
      } else {
        // Unsaved user - send phone number only
        debugPrint(
          '📊 Sending UNSAVED user data: ${_currentCall?.phoneNumber}',
        );
        await FlutterOverlayWindow.shareData({
          'name': null,
          'phone': _currentCall?.phoneNumber ?? 'Unknown',
          'email': null,
          'category': null,
          'status': null,
          'isVip': false,
          'description': null,
          'totalCalls': 0,
          'lastCallTime': null,
          'callTime': DateTime.now().toIso8601String(),
          'isSaved': false,
        });
      }

      debugPrint('✅ Data sent to overlay successfully!');
    } catch (e) {
      debugPrint('❌ ERROR showing system overlay: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  // Public method for testing system overlay
  Future<void> testSystemOverlay(Lead? lead) async {
    debugPrint('🧪 Test overlay called');
    await _showSystemOverlay(lead);
  }

  /// Simulate an incoming call for testing purposes
  /// This mimics the real _handleIncomingCall behavior
  Future<void> simulateIncomingCall(String phoneNumber) async {
    debugPrint('🧪 SIMULATING INCOMING CALL from: $phoneNumber');

    // Simulate exactly what happens during a real call
    final existingLead = await _dbService.getLeadByPhone(phoneNumber);

    _currentCall = CallModel(
      phoneNumber: phoneNumber,
      callerName: existingLead?.name,
      callTime: DateTime.now(),
      isIncoming: true,
    );

    _callerLead = existingLead;
    _hasIncomingCall = true;

    // Show overlays just like real call
    if (_callerLead != null) {
      debugPrint('✅ Saved lead found! Showing overlays...');
      if (_overlayService != null) {
        _overlayService!.showFloatingIcon(_callerLead!);
      }

      // Delegate System Overlay to Background Service
      FlutterBackgroundService().invoke("simulate_incoming_call", {
        "phone": phoneNumber,
      });
    } else {
      debugPrint('❌ No lead found - showing overlay with phone only');
      // Delegate System Overlay to Background Service
      FlutterBackgroundService().invoke("simulate_incoming_call", {
        "phone": phoneNumber,
      });
    }

    notifyListeners();
  }

  /// End the simulated call
  void endSimulatedCall() {
    debugPrint('🧪 ENDING SIMULATED CALL');
    _handleCallEnded();
  }

  void _handleCallStarted() {
    _isCallActive = true;
    _hasIncomingCall = false;
    _callStartTime = DateTime.now();
    _callDuration = 0;

    // Show floating icon if caller is a saved lead
    if (_callerLead != null && _overlayService != null) {
      _overlayService!.showFloatingIcon(_callerLead!);
    }

    notifyListeners();
  }

  Future<void> _handleCallEnded() async {
    _isCallActive = false;

    if (_callStartTime != null) {
      _callDuration = DateTime.now().difference(_callStartTime!).inSeconds;
    }

    if (_callerLead != null && _currentCall != null) {
      final callHistory = CallHistory(
        leadId: _callerLead!.id!,
        callTime: _currentCall!.callTime,
        duration: _callDuration,
        isIncoming: _currentCall!.isIncoming,
      );
      await _dbService.insertCallHistory(callHistory);
      await _dbService.updateLeadCallStats(
        _callerLead!.id!,
        _currentCall!.callTime,
      );
    }

    // Don't clear current call immediately to allow saving post-call,
    // but reset active state.
    _callStartTime = null;

    // Hide floating icon when call ends
    if (_overlayService != null) {
      _overlayService!.hideFloatingIcon();
    }

    // Close system overlay: DELEGATED TO BACKGROUND SERVICE
    // The Background Service listens to CALL_ENDED.

    notifyListeners();
  }

  Future<void> _handleOutgoingCall(String phoneNumber) async {
    debugPrint('📞 OUTGOING CALL to: $phoneNumber');

    final existingLead = await _dbService.getLeadByPhone(phoneNumber);

    debugPrint('🔍 Lead lookup result: ${existingLead?.name ?? "NOT FOUND"}');

    _currentCall = CallModel(
      phoneNumber: phoneNumber,
      callerName: existingLead?.name,
      callTime: DateTime.now(),
      isIncoming: false,
    );

    _callerLead = existingLead;
    _hasIncomingCall = false; // Outgoing calls are not "incoming"

    // Show system-wide overlay if caller is a saved lead
    if (_callerLead != null) {
      debugPrint('✅ Saved lead found! Showing overlays...');
      // Show in-app overlay and automatically open details popup for saved users
      if (_overlayService != null) {
        debugPrint('📱 Showing in-app floating icon');
        _overlayService!.showFloatingIcon(_callerLead!);
      }

      // Show system overlay: DELEGATED TO BACKGROUND SERVICE
    } else {
      debugPrint(
        '❌ No lead found for this number - showing overlay with phone only',
      );
      // Background Service handles this.
    }

    notifyListeners();
  }

  void acceptCall() {
    _hasIncomingCall = false;
    _isCallActive = true;
    _callStartTime = DateTime.now();
    _callDuration = 0;
    notifyListeners();
  }

  void rejectCall() {
    _hasIncomingCall = false;
    _currentCall = null;
    _callerLead = null;
    _callStartTime = null;
    _callDuration = 0;
    notifyListeners();
  }

  void endCall() {
    // This is a manual end, the listener will handle the rest
    _handleCallEnded();
  }

  Future<void> saveLead(Lead lead) async {
    final newLeadId = await _dbService.insertLead(lead);
    _callerLead = lead.copyWith(id: newLeadId);
    notifyListeners();
  }

  void clearCall() {
    _currentCall = null;
    _callerLead = null;
    _hasIncomingCall = false;
    _isCallActive = false;
    _callStartTime = null;
    _callDuration = 0;

    // Hide floating icon when clearing call
    if (_overlayService != null) {
      _overlayService!.hideFloatingIcon();
    }

    notifyListeners();
  }

  // Make outgoing call (prepare for it)
  Future<void> makeCall(String phoneNumber) async {
    final existingLead = await _dbService.getLeadByPhone(phoneNumber);

    _currentCall = CallModel(
      phoneNumber: phoneNumber,
      callerName: existingLead?.name,
      callTime: DateTime.now(),
      isIncoming: false,
    );

    _callerLead = existingLead;
    notifyListeners();
  }
}
