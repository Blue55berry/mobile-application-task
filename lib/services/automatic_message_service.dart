import 'package:flutter/foundation.dart';
import '../models/automatic_message_model.dart';
import 'database_service.dart';

class AutomaticMessageService extends ChangeNotifier {
  List<AutomaticMessage> _messages = [];
  bool _isLoading = false;

  List<AutomaticMessage> get messages => _messages;
  bool get isLoading => _isLoading;

  // Load all automatic messages
  Future<void> loadMessages() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseService().database;
      final maps = await db.query(
        'automatic_messages',
        orderBy: 'created_at DESC',
      );

      _messages = maps.map((map) => AutomaticMessage.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error loading automatic messages: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add new message
  Future<bool> addMessage(String name, String message, String trigger) async {
    try {
      final newMessage = AutomaticMessage(
        name: name,
        message: message,
        trigger: trigger,
        createdAt: DateTime.now(),
      );

      final db = await DatabaseService().database;
      final id = await db.insert('automatic_messages', newMessage.toMap());

      _messages.insert(0, newMessage.copyWith(id: id));
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding automatic message: $e');
      return false;
    }
  }

  // Update message
  Future<bool> updateMessage(AutomaticMessage message) async {
    try {
      final db = await DatabaseService().database;
      await db.update(
        'automatic_messages',
        message.toMap(),
        where: 'id = ?',
        whereArgs: [message.id],
      );

      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _messages[index] = message;
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Error updating automatic message: $e');
      return false;
    }
  }

  // Delete message
  Future<bool> deleteMessage(int id) async {
    try {
      final db = await DatabaseService().database;
      await db.delete('automatic_messages', where: 'id = ?', whereArgs: [id]);

      _messages.removeWhere((m) => m.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting automatic message: $e');
      return false;
    }
  }

  // Toggle message enabled/disabled
  Future<bool> toggleMessage(AutomaticMessage message) async {
    final updated = message.copyWith(isEnabled: !message.isEnabled);
    return await updateMessage(updated);
  }

  // Get message by trigger type
  AutomaticMessage? getMessageByTrigger(String trigger) {
    try {
      return _messages.firstWhere((m) => m.trigger == trigger && m.isEnabled);
    } catch (e) {
      return null;
    }
  }
}
