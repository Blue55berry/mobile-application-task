import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'leads_service.dart';

/// Service to handle broadcast events from native Android layer
/// for lead-related operations (new lead saved, lead updated)
class LeadBroadcastReceiver {
  static const _methodChannel = MethodChannel('com.example.sbs/call_methods');

  final LeadsService _leadsService;
  final GlobalKey<NavigatorState>? navigatorKey;

  LeadBroadcastReceiver({required LeadsService leadsService, this.navigatorKey})
    : _leadsService = leadsService;

  /// Initialize broadcast listener
  void initialize() {
    _methodChannel.setMethodCallHandler(_handleMethodCall);
    debugPrint('📡 LeadBroadcastReceiver initialized');
  }

  /// Handle method calls from native Android
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('📱 Received broadcast: ${call.method}');

    switch (call.method) {
      case 'onNewLeadSaved':
        await _handleNewLeadSaved(call.arguments);
        break;

      case 'onLeadUpdated':
        await _handleLeadUpdated(call.arguments);
        break;

      default:
        debugPrint('⚠️ Unhandled broadcast method: ${call.method}');
    }
  }

  /// Handle new lead saved event
  Future<void> _handleNewLeadSaved(dynamic arguments) async {
    try {
      final Map<String, dynamic> data = Map<String, dynamic>.from(
        arguments as Map,
      );
      final leadId = data['leadId'] as int?;
      final name = data['name'] as String?;
      final phone = data['phone'] as String?;
      final category = data['category'] as String?;

      debugPrint(
        '✅ New lead saved event: $name (ID: $leadId, Phone: $phone, Category: $category)',
      );

      // Refresh leads list
      await _leadsService.fetchLeads();

      // Show notification to user
      _showSnackBar('✅ New lead "$name" saved successfully');
    } catch (e) {
      debugPrint('❌ Error handling new lead saved: $e');
    }
  }

  /// Handle lead updated event
  Future<void> _handleLeadUpdated(dynamic arguments) async {
    try {
      final Map<String, dynamic> data = Map<String, dynamic>.from(
        arguments as Map,
      );
      final leadId = data['leadId'] as int?;
      final name = data['name'] as String?;
      final category = data['category'] as String?;

      debugPrint(
        '🔄 Lead updated event: $name (ID: $leadId, Category: $category)',
      );

      // Refresh leads list
      await _leadsService.fetchLeads();

      // Show notification to user
      _showSnackBar('🔄 Lead "$name" updated');
    } catch (e) {
      debugPrint('❌ Error handling lead updated: $e');
    }
  }

  /// Show snackbar notification
  void _showSnackBar(String message) {
    final context = navigatorKey?.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green[700],
        ),
      );
    }
  }

  /// Dispose resources
  void dispose() {
    _methodChannel.setMethodCallHandler(null);
    debugPrint('📡 LeadBroadcastReceiver disposed');
  }
}
