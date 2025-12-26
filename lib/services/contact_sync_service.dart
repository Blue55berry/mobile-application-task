import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../services/database_service.dart';
import '../models/lead_model.dart';

/// Service to sync phone contacts to CRM database
class ContactSyncService {
  final DatabaseService _dbService = DatabaseService();

  /// Import all phone contacts to CRM
  Future<Map<String, int>> importAllContacts() async {
    int successCount = 0;
    int skipCount = 0;
    int errorCount = 0;

    try {
      // Check permission
      final status = await Permission.contacts.status;
      if (!status.isGranted) {
        debugPrint('❌ Contacts permission not granted');
        throw Exception('Contacts permission required');
      }

      debugPrint('📱 Starting contact import...');

      // Get all contacts from phone
      final List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
      );
      debugPrint('📱 Found ${contacts.length} contacts in phone');

      for (Contact contact in contacts) {
        try {
          // Skip if no phone number
          if (contact.phones.isEmpty) {
            skipCount++;
            continue;
          }

          final String name = contact.displayName;
          final String phoneNumber = contact.phones.first.number;

          // Clean phone number
          final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

          if (cleanNumber.length < 6) {
            skipCount++;
            continue;
          }

          // Check if contact already exists in CRM
          final db = await _dbService.database;
          final existing = await db.query(
            'leads',
            where: 'phoneNumber = ?',
            whereArgs: [cleanNumber],
            limit: 1,
          );

          if (existing.isNotEmpty) {
            skipCount++;
            continue;
          }

          // Create new lead with source='phone' to identify as imported
          final lead = Lead(
            id: 0,
            name: name,
            phoneNumber: cleanNumber,
            email: contact.emails.isNotEmpty
                ? contact.emails.first.address
                : null,
            category: 'Imported', // Mark as imported from contacts
            status: 'New',
            isVip: false,
            createdAt: DateTime.now(),
            source: 'phone', // Mark as phone import
          );

          // Save to database
          await db.insert('leads', lead.toMap());
          successCount++;

          debugPrint('✅ Imported: $name - $cleanNumber');
        } catch (e) {
          errorCount++;
          debugPrint('❌ Error importing contact: $e');
        }
      }

      debugPrint(
        '📊 Import complete: $successCount added, $skipCount skipped, $errorCount errors',
      );

      return {
        'success': successCount,
        'skipped': skipCount,
        'errors': errorCount,
      };
    } catch (e) {
      debugPrint('❌ Contact import failed: $e');
      rethrow;
    }
  }

  /// Request contacts permission and import
  Future<Map<String, int>> requestAndImport(BuildContext context) async {
    final status = await Permission.contacts.request();

    if (status.isGranted) {
      // Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Importing contacts...'),
              ],
            ),
          ),
        );
      }

      // Import contacts
      final result = await importAllContacts();

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();

        // Show result
        final total =
            result['success']! + result['skipped']! + result['errors']!;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import Complete'),
            content: Text(
              '✅ ${result['success']} contacts imported\n'
              '⏭️ ${result['skipped']} already exist\n'
              '❌ ${result['errors']} errors\n\n'
              'Total: $total contacts processed',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      return result;
    } else if (status.isPermanentlyDenied) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'Contacts permission is required to import phone contacts. '
              'Please enable it in app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  openAppSettings();
                  Navigator.of(context).pop();
                },
                child: const Text('Settings'),
              ),
            ],
          ),
        );
      }
    }

    return {'success': 0, 'skipped': 0, 'errors': 0};
  }
}
