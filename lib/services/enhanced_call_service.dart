// lib/services/enhanced_call_service.dart (updated)

import 'package:flutter/material.dart';
import 'package:phone_state/phone_state.dart';
import '../models/call_model.dart';
import '../models/lead_model.dart';
import '../models/call_history_model.dart';
import 'database_service.dart';
import 'call_overlay_service.dart';

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
  }

  void setOverlayService(CallOverlayService overlayService) {
    _overlayService = overlayService;
  }

  // Lead operations (saving, updating)
  Future<void> saveLead(Lead lead) async {
    final newLeadId = await _dbService.insertLead(lead);
    _callerLead = lead.copyWith(id: newLeadId);
    notifyListeners();
  }

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

    _currentCall = CallModel(
      phoneNumber: phoneNumber,
      callerName: existingLead?.name,
      callTime: DateTime.now(),
      isIncoming: true,
    );

    _callerLead = existingLead;
    _hasIncomingCall = true;

    // Show in-app floating icon for saved users
    if (_callerLead != null && _overlayService != null) {
      _overlayService!.showFloatingIcon(_callerLead!);
    }

    notifyListeners();
  }

  void _handleCallStarted() {
    _isCallActive = true;
    _hasIncomingCall = false;
    _callStartTime = DateTime.now();
    _callDuration = 0;

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

    _callStartTime = null;
    if (_overlayService != null) {
      _overlayService!.hideFloatingIcon();
    }
    notifyListeners();
  }

  Future<void> _handleOutgoingCall(String phoneNumber) async {
    debugPrint('📞 OUTGOING CALL to: $phoneNumber');
    final existingLead = await _dbService.getLeadByPhone(phoneNumber);

    _currentCall = CallModel(
      phoneNumber: phoneNumber,
      callerName: existingLead?.name,
      callTime: DateTime.now(),
      isIncoming: false,
    );

    _callerLead = existingLead;
    _hasIncomingCall = false;

    if (_callerLead != null && _overlayService != null) {
      _overlayService!.showFloatingIcon(_callerLead!);
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
    _handleCallEnded();
  }

  void clearCall() {
    _currentCall = null;
    _callerLead = null;
    _hasIncomingCall = false;
    _isCallActive = false;
    _callStartTime = null;
    _callDuration = 0;

    if (_overlayService != null) {
      _overlayService!.hideFloatingIcon();
    }
    notifyListeners();
  }

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
