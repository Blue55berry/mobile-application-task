import 'package:flutter/material.dart';
import '../models/label_model.dart';
import 'database_service.dart';

class LabelService extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  List<Label> _labels = [];
  bool _isLoading = false;

  List<Label> get labels => _labels;
  bool get isLoading => _isLoading;

  LabelService() {
    loadLabels();
  }

  Future<void> initializeDefaultLabels() async {
    final existingLabels = await _dbService.getLabels();

    // Define new default labels
    final defaultLabels = [
      Label(name: 'Vendor', color: '#FF6B35'), // Orange-red
      Label(name: 'Internship', color: '#4ECDC4'), // Teal
      Label(name: 'Job', color: '#45B7D1'), // Sky blue
      Label(name: 'Business', color: '#FFA07A'), // Light salmon
      Label(name: 'Course', color: '#9B59B6'), // Purple
    ];

    if (existingLabels.isEmpty) {
      // No labels exist - create defaults
      for (var label in defaultLabels) {
        await _dbService.insertLabel(label);
      }
      await loadLabels();
    } else {
      // Check if we have old default labels that need migration
      final oldDefaults = ['Client', 'Partner', 'Supplier', 'Other'];
      final hasOldDefaults = existingLabels.any(
        (label) => oldDefaults.contains(label.name),
      );

      if (hasOldDefaults) {
        // Migrate: Delete old defaults and add new ones
        for (var label in existingLabels) {
          if (oldDefaults.contains(label.name)) {
            try {
              if (label.id != null) {
                await _dbService.deleteLabel(label.id!);
              }
            } catch (e) {
              debugPrint('Could not delete old label ${label.name}: $e');
            }
          }
        }

        // Add new defaults
        for (var label in defaultLabels) {
          // Check if it doesn't already exist
          if (!existingLabels.any((l) => l.name == label.name)) {
            await _dbService.insertLabel(label);
          }
        }

        await loadLabels();
      }
    }
  }

  Future<void> loadLabels() async {
    _isLoading = true;
    notifyListeners();
    try {
      await initializeDefaultLabels(); // Call this before loading to ensure defaults are present
      _labels = await _dbService.getLabels();
    } catch (e) {
      debugPrint('Error loading labels: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addLabel(String name, String color) async {
    try {
      final newLabel = Label(name: name, color: color);
      final id = await _dbService.insertLabel(newLabel);
      final savedLabel = newLabel.copyWith(id: id);
      _labels.add(savedLabel);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding label: $e');
      rethrow; // Re-throw to show error in UI
    }
  }

  Future<void> updateLabel(Label label) async {
    try {
      await _dbService.updateLabel(label);
      final index = _labels.indexWhere((l) => l.id == label.id);
      if (index != -1) {
        _labels[index] = label;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating label: $e');
      rethrow;
    }
  }

  Future<void> deleteLabel(int id) async {
    try {
      // Check if label is in use
      final inUse = await _dbService.isLabelInUse(id);
      if (inUse) {
        throw Exception('Cannot delete label that is currently in use');
      }

      await _dbService.deleteLabel(id);
      _labels.removeWhere((l) => l.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting label: $e');
      rethrow;
    }
  }

  // Get label by name
  Label? getLabelByName(String name) {
    try {
      return _labels.firstWhere((l) => l.name == name);
    } catch (e) {
      return null;
    }
  }

  // Get color for a label name
  String getColorForLabel(String labelName) {
    final label = getLabelByName(labelName);
    return label?.color ?? '#6C5CE7'; // Default purple
  }

  // Check if label name already exists
  bool labelExists(String name) {
    return _labels.any((l) => l.name.toLowerCase() == name.toLowerCase());
  }
}
