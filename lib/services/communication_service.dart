import '../models/communication_model.dart';
import 'database_service.dart';

/// Unified service for managing all types of communications
/// Orchestrates calls, emails, SMS, and WhatsApp interactions
class CommunicationService {
  final DatabaseService _db = DatabaseService();

  /// Log a call communication
  Future<int> logCall({
    required int leadId,
    required String direction, // 'inbound' or 'outbound'
    required String phoneNumber,
    int? durationSeconds,
    String? notes,
  }) async {
    final communication = Communication(
      leadId: leadId,
      type: 'call',
      direction: direction,
      phoneNumber: phoneNumber,
      timestamp: DateTime.now(),
      status: 'completed',
      body: notes,
      metadata: durationSeconds != null
          ? {'duration': durationSeconds.toString()}
          : null,
    );

    return await _db.insertCommunication(communication);
  }

  /// Log an email communication
  Future<int> logEmail({
    required int leadId,
    required String direction,
    required String emailAddress,
    required String subject,
    String? body,
    List<String>? attachments,
    String status = 'sent',
  }) async {
    final communication = Communication(
      leadId: leadId,
      type: 'email',
      direction: direction,
      emailAddress: emailAddress,
      subject: subject,
      body: body,
      timestamp: DateTime.now(),
      status: status,
      metadata: attachments != null && attachments.isNotEmpty
          ? {'attachments': attachments.join(',')}
          : null,
    );

    return await _db.insertCommunication(communication);
  }

  /// Log an SMS communication
  Future<int> logSMS({
    required int leadId,
    required String direction,
    required String phoneNumber,
    required String message,
    String status = 'sent',
  }) async {
    final communication = Communication(
      leadId: leadId,
      type: 'sms',
      direction: direction,
      phoneNumber: phoneNumber,
      body: message,
      timestamp: DateTime.now(),
      status: status,
    );

    return await _db.insertCommunication(communication);
  }

  /// Log a WhatsApp communication
  Future<int> logWhatsApp({
    required int leadId,
    required String direction,
    required String phoneNumber,
    required String message,
  }) async {
    final communication = Communication(
      leadId: leadId,
      type: 'whatsapp',
      direction: direction,
      phoneNumber: phoneNumber,
      body: message,
      timestamp: DateTime.now(),
      status: 'sent', // WhatsApp sends via external app, assume sent
    );

    return await _db.insertCommunication(communication);
  }

  /// Get all communications for a specific lead
  Future<List<Communication>> getCommunicationsForLead(int leadId) async {
    return await _db.getCommunicationsForLead(leadId);
  }

  /// Get all communications with optional filters
  Future<List<Communication>> getAllCommunications({
    String? type,
    DateTime? since,
  }) async {
    return await _db.getAllCommunications(type: type, since: since);
  }

  /// Update communication status (useful for emails/SMS delivery tracking)
  Future<void> updateStatus(int communicationId, String status) async {
    await _db.updateCommunicationStatus(communicationId, status);
  }

  /// Get communication statistics for dashboard
  Future<Map<String, int>> getStatistics({Duration? period}) async {
    final since = period ?? const Duration(days: 7);
    final allComms = await _db.getAllCommunications(
      since: DateTime.now().subtract(since),
    );

    final stats = <String, int>{
      'total': allComms.length,
      'calls': 0,
      'emails': 0,
      'sms': 0,
      'whatsapp': 0,
    };

    for (final comm in allComms) {
      stats[comm.type] = (stats[comm.type] ?? 0) + 1;
    }

    return stats;
  }

  /// Get recent communications count
  Future<int> getRecentCount({Duration? since}) async {
    return await _db.getRecentCommunicationsCount(since: since);
  }

  /// Delete a communication
  Future<void> deleteCommunication(int id) async {
    await _db.deleteCommunication(id);
  }

  /// Stream of communications for real-time updates (if needed)
  Stream<List<Communication>> getCommunicationsStream(int leadId) async* {
    // For real-time updates, we'd implement a StreamController
    // For now, just yield once
    yield await getCommunicationsForLead(leadId);
  }
}
