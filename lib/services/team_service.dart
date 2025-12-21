import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage team/company information
class TeamService extends ChangeNotifier {
  String? _companyName;
  String? _companySize;
  String? _companyType;
  List<String> _teamMembers = [];

  // Getters
  String? get companyName => _companyName;
  String? get companySize => _companySize;
  String? get companyType => _companyType;
  List<String> get teamMembers => List.unmodifiable(_teamMembers);

  bool get hasTeamData => _companyName != null && _companyName!.isNotEmpty;
  int get memberCount => _teamMembers.length;

  /// Initialize service and load saved data
  Future<void> initialize() async {
    await _loadTeamData();
  }

  /// Save company profile
  Future<void> saveCompanyProfile({
    required String name,
    required String size,
    required String type,
  }) async {
    _companyName = name;
    _companySize = size;
    _companyType = type;

    await _persistTeamData();
    notifyListeners();
  }

  /// Add team member
  Future<void> addMember(String email) async {
    if (!_teamMembers.contains(email)) {
      _teamMembers.add(email);
      await _persistTeamData();
      notifyListeners();
    }
  }

  /// Remove team member
  Future<void> removeMember(String email) async {
    _teamMembers.remove(email);
    await _persistTeamData();
    notifyListeners();
  }

  /// Clear all team members
  Future<void> clearMembers() async {
    _teamMembers.clear();
    await _persistTeamData();
    notifyListeners();
  }

  /// Load team data from SharedPreferences
  Future<void> _loadTeamData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _companyName = prefs.getString('team_company_name');
      _companySize = prefs.getString('team_company_size');
      _companyType = prefs.getString('team_company_type');

      final membersJson = prefs.getString('team_members');
      if (membersJson != null) {
        final List<dynamic> membersList = jsonDecode(membersJson);
        _teamMembers = membersList.cast<String>();
      }

      notifyListeners();
      debugPrint('✅ Team data loaded: $_companyName');
    } catch (e) {
      debugPrint('❌ Error loading team data: $e');
    }
  }

  /// Save team data to SharedPreferences
  Future<void> _persistTeamData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_companyName != null) {
        await prefs.setString('team_company_name', _companyName!);
      }
      if (_companySize != null) {
        await prefs.setString('team_company_size', _companySize!);
      }
      if (_companyType != null) {
        await prefs.setString('team_company_type', _companyType!);
      }

      await prefs.setString('team_members', jsonEncode(_teamMembers));

      debugPrint('💾 Team data saved');
    } catch (e) {
      debugPrint('❌ Error saving team data: $e');
    }
  }
}
