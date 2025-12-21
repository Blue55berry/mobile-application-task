import 'package:flutter/material.dart';
import '../models/lead_model.dart';
import 'database_service.dart';
import 'task_service.dart';

class LeadsService extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  late TaskService _taskService;
  List<Lead> _leads = [];

  List<Lead> get leads => _leads;

  LeadsService(this._taskService) {
    fetchLeads();
  }

  void update(TaskService taskService) {
    _taskService = taskService;
  }

  Future<void> fetchLeads() async {
    _leads = await _dbService.getLeads();
    notifyListeners();
  }

  Future<void> addLead(Lead lead) async {
    await _dbService.insertLead(lead);
    _taskService.addTaskForLead(lead);
    await fetchLeads();
  }

  Future<void> updateLead(Lead lead) async {
    await _dbService.updateLead(lead);
    await fetchLeads();
  }

  Future<void> deleteLead(int id) async {
    await _dbService.deleteLead(id);
    await fetchLeads();
  }
}
