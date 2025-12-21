import 'package:flutter/material.dart';
import '../models/call_model.dart';
import '../models/lead_model.dart';
import 'database_service.dart';

class CallService extends ChangeNotifier {
  CallModel? _currentCall;
  bool _hasIncomingCall = false;
  final DatabaseService _dbService = DatabaseService();

  CallModel? get currentCall => _currentCall;
  bool get hasIncomingCall => _hasIncomingCall;

  void simulateIncomingCall(String phoneNumber) {
    _currentCall = CallModel(
      phoneNumber: phoneNumber,
      callTime: DateTime.now(),
      isIncoming: true,
    );
    _hasIncomingCall = true;
    notifyListeners();
  }

  void acceptCall() {
    // Handle call acceptance
  }

  void rejectCall() {
    _hasIncomingCall = false;
    _currentCall = null;
    notifyListeners();
  }

  Future<void> saveContact(String category) async {
    if (_currentCall != null) {
      final lead = Lead(
        name: 'Unknown',
        category: category,
        status: 'New',
        createdAt: DateTime.now(),
        phoneNumber: _currentCall!.phoneNumber,
      );

      await _dbService.insertLead(lead);
      _hasIncomingCall = false;
      _currentCall = null;
      notifyListeners();
    }
  }
}
