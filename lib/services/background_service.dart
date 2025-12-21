import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:phone_state/phone_state.dart';
import '../models/lead_model.dart';
import 'database_service.dart';

// Entry point for the background service
@pragma('vm:entry-point')
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      foregroundServiceNotificationId: 888,
      initialNotificationTitle: 'SBS Call Monitor',
      initialNotificationContent: 'Active and monitoring calls',
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  debugPrint('✅ Background service configured');
  await service.startService();
  debugPrint('✅ Background service started');
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  debugPrint('🚀 Background Service onStart called');
  // Ensure Flutter binding is initialized
  DartPluginRegistrant.ensureInitialized();
  debugPrint('✅ DartPluginRegistrant initialized');

  final dbService = DatabaseService();
  debugPrint('✅ DatabaseService created');

  // Check overlay permission immediately
  final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
  debugPrint('🔐 Overlay permission on start: $hasPermission');

  if (!hasPermission) {
    debugPrint('⚠️ Requesting overlay permission...');
    await FlutterOverlayWindow.requestPermission();
    final requestedPermission =
        await FlutterOverlayWindow.isPermissionGranted();
    debugPrint('🔐 Overlay permission after request: $requestedPermission');
  }

  // Listen to phone state
  debugPrint('👂 Setting up PhoneState listener...');
  PhoneState.stream.listen((event) async {
    debugPrint(
        "📱 BG Service Detected Call State: ${event.status} for number: ${event.number}");

    switch (event.status) {
      case PhoneStateStatus.CALL_INCOMING:
        debugPrint('Handling incoming call event.');
        await _handleIncomingCall(event.number ?? 'Unknown', dbService);
        break;
      case PhoneStateStatus.CALL_OUTGOING:
        debugPrint('Handling outgoing call event.');
        await _handleOutgoingCall(event.number ?? 'Unknown', dbService);
        break;
      case PhoneStateStatus.CALL_ENDED:
        debugPrint('Handling call ended event.');
        await _handleCallEnded(dbService);
        break;
      case PhoneStateStatus.CALL_STARTED:
        debugPrint('Handling call started event.');
        await _handleCallStarted();
        break;
      default:
        debugPrint('Unhandled PhoneStateStatus: ${event.status}');
        break;
    }
  });

  // Listen for custom events from the main app
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Listen for simulation events from Main UI
  service.on('simulate_incoming_call').listen((event) async {
    final phone = event?['phone'] as String?;
    if (phone != null) {
      await _handleIncomingCall(phone, dbService);
    }
  });
}

Lead? _bgCallerLead;

Future<void> _handleCallStarted() async {
  debugPrint('📞 BG Service: CALL STARTED. Sharing event.');
  await FlutterOverlayWindow.shareData({'event': 'call_started'});
}

Future<void> _handleIncomingCall(
  String phoneNumber,
  DatabaseService dbService,
) async {
  debugPrint('📞 BG Service: INCOMING CALL from: $phoneNumber');
  debugPrint('🔍 Checking database for lead...');

  final existingLead = await dbService.getLeadByPhone(phoneNumber);

  debugPrint('✅ Found lead for incoming call: ${existingLead?.name ?? "NONE"}');
  _bgCallerLead = existingLead;

  debugPrint('🎯 Calling _showSystemOverlay for incoming call...');
  await _showSystemOverlay(_bgCallerLead, phoneNumber, isIncoming: true);
  debugPrint('✅ _showSystemOverlay completed for incoming call.');
}

Future<void> _handleOutgoingCall(
  String phoneNumber,
  DatabaseService dbService,
) async {
  debugPrint('📞 BG Service: OUTGOING CALL to: $phoneNumber');
  debugPrint('🔍 Checking database for lead for outgoing call...');

  final existingLead = await dbService.getLeadByPhone(phoneNumber);

  debugPrint('✅ Found lead for outgoing call: ${existingLead?.name ?? "NONE"}');
  _bgCallerLead = existingLead;

  debugPrint('🎯 Calling _showSystemOverlay for outgoing call...');
  await _showSystemOverlay(_bgCallerLead, phoneNumber, isIncoming: false);
  debugPrint('✅ _showSystemOverlay completed for outgoing call.');
}

Future<void> _handleCallEnded(DatabaseService dbService) async {
  debugPrint('📞 BG Service: CALL ENDED. Closing overlay.');

  // Close overlay
  try {
    await FlutterOverlayWindow.closeOverlay();
    debugPrint('✅ Overlay closed successfully.');
  } catch (e) {
    debugPrint('❌ Error closing overlay (might not be open): $e');
  }
}

Future<void> _showSystemOverlay(Lead? lead, String phoneNumber,
    {required bool isIncoming}) async {
  debugPrint(
    '🎬 _showSystemOverlay START - Lead: ${lead?.name ?? "NONE"}, Phone: $phoneNumber, IsIncoming: $isIncoming',
  );

  try {
    final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
    debugPrint(
        '🔐 Overlay permission check inside _showSystemOverlay: $hasPermission');

    if (hasPermission) {
      debugPrint('✅ Permission granted! Proceeding to show overlay...');

      if (lead != null) {
        debugPrint('👤 Attempting to show SAVED USER overlay for: ${lead.name}');
        // SAVED USER: Bottom-sheet CRM Panel (Expanded)
        await FlutterOverlayWindow.showOverlay(
          enableDrag: false, // Bottom sheet is fixed
          overlayTitle: "SBS CRM Panel",
          overlayContent: "Contact: ${lead.name}",
          flag: OverlayFlag.defaultFlag,
          visibility: NotificationVisibility.visibilityPublic,
          positionGravity: PositionGravity.none,
          height: 520,
          width: WindowSize.matchParent,
        );

        // Share data
        debugPrint('📤 Sharing data for SAVED USER overlay...');
        await FlutterOverlayWindow.shareData({
          'name': lead.name,
          'phone': lead.phoneNumber ?? '',
          'email': lead.email ?? '',
          'category': lead.category,
          'status': lead.status,
          'isVip': lead.isVip,
          'description': lead.description ?? '',
          'totalCalls': lead.totalCalls ?? 0,
          'lastCallDate': lead.lastCallDate?.toIso8601String(),
          'callTime': DateTime.now().toIso8601String(),
          'isSaved': true,
          'isIncoming': isIncoming,
        });
        debugPrint('✅ Saved user overlay shown and data shared successfully');
      } else {
        debugPrint('❓ Attempting to show NEW LEAD overlay for: $phoneNumber');
        // UNSAVED USER: New Lead Bottom Sheet
        await FlutterOverlayWindow.showOverlay(
          enableDrag: false,
          overlayTitle: "SBS New Lead",
          overlayContent: "Unknown Caller",
          flag: OverlayFlag.defaultFlag,
          visibility: NotificationVisibility.visibilityPublic,
          positionGravity: PositionGravity.none,
          height: 450,
          width: WindowSize.matchParent,
        );

        // Share data
        debugPrint('📤 Sharing data for NEW LEAD overlay...');
        await FlutterOverlayWindow.shareData({
          'name': null,
          'phone': phoneNumber,
          'callTime': DateTime.now().toIso8601String(),
          'isSaved': false,
          'isIncoming': isIncoming,
        });
        debugPrint('✅ New lead overlay shown and data shared successfully');
      }
    } else {
      debugPrint("⚠️ BG Service: Overlay permission NOT granted.");
      debugPrint("🔄 Requesting permission now from _showSystemOverlay...");
      await FlutterOverlayWindow.requestPermission();
      final afterRequestPermission =
          await FlutterOverlayWindow.isPermissionGranted();
      debugPrint(
          '🔐 Overlay permission after request from _showSystemOverlay: $afterRequestPermission');
    }
  } catch (e, st) {
    debugPrint("❌ BG Service: CRITICAL ERROR showing overlay: $e");
    debugPrint("📋 Stack trace: $st");
  }
}
