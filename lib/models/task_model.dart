import 'package:flutter/material.dart';

class Task {
  final int? id;
  final String title;
  final String description;
  final DateTime dueDate;
  final TimeOfDay? dueTime;
  final String category;
  final String priority;
  final bool isCompleted;
  final int? leadId; // Link to a specific lead
  final DateTime? reminder;

  Task({
    this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    this.dueTime,
    required this.category,
    required this.priority,
    required this.isCompleted,
    this.leadId,
    this.reminder,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'dueTime': dueTime != null ? '${dueTime!.hour}:${dueTime!.minute}' : null,
      'category': category,
      'priority': priority,
      'isCompleted': isCompleted ? 1 : 0,
      'leadId': leadId,
      'reminder': reminder?.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    TimeOfDay? parsedTime;
    if (map['dueTime'] != null) {
      final parts = (map['dueTime'] as String).split(':');
      if (parts.length == 2) {
        parsedTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }

    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      dueDate: DateTime.parse(map['dueDate']),
      dueTime: parsedTime,
      category: map['category'],
      priority: map['priority'],
      isCompleted: map['isCompleted'] == 1,
      leadId: map['leadId'],
      reminder: map['reminder'] != null
          ? DateTime.parse(map['reminder'])
          : null,
    );
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? dueDate,
    TimeOfDay? dueTime,
    String? category,
    String? priority,
    bool? isCompleted,
    int? leadId,
    DateTime? reminder,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      leadId: leadId ?? this.leadId,
      reminder: reminder ?? this.reminder,
    );
  }
}
