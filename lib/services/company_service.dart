import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/company_model.dart';
import 'database_service.dart';

class CompanyService extends ChangeNotifier {
  List<Company> _companies = [];
  Company? _activeCompany;
  bool _isLoading = false;
  bool _isInitialized = false;

  List<Company> get companies => _companies;
  Company? get activeCompany => _activeCompany;
  bool get isLoading => _isLoading;
  bool get hasCompanies => _companies.isNotEmpty;
  bool get isInitialized => _isInitialized;

  // Initialize service with caching
  Future<void> initialize() async {
    if (_isInitialized) return; // Prevent multiple initializations

    await loadCompanies();
    await _loadActiveCompanyId();
    _isInitialized = true;
  }

  // Load active company ID from cache
  Future<void> _loadActiveCompanyId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeId = prefs.getInt('active_company_id');
      if (activeId != null && _companies.isNotEmpty) {
        _activeCompany = _companies.firstWhere(
          (c) => c.id == activeId,
          orElse: () => _companies.first,
        );
      } else if (_companies.isNotEmpty && _activeCompany == null) {
        _activeCompany = _companies.first;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading active company: $e');
    }
  }

  // Save active company ID to cache
  Future<void> _saveActiveCompanyId(int? id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id != null) {
        await prefs.setInt('active_company_id', id);
      }
    } catch (e) {
      debugPrint('Error saving active company: $e');
    }
  }

  // Load all companies
  Future<void> loadCompanies() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseService().database;
      final maps = await db.query('companies', orderBy: 'created_at DESC');

      _companies = maps.map((map) => Company.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error loading companies: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add new company
  Future<bool> addCompany(Company company) async {
    try {
      final db = await DatabaseService().database;
      final id = await db.insert('companies', company.toMap());

      final newCompany = company.copyWith(id: id);
      _companies.insert(0, newCompany);

      // Set as active if it's the first company
      if (_companies.length == 1) {
        _activeCompany = newCompany;
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding company: $e');
      return false;
    }
  }

  // Update company
  Future<bool> updateCompany(Company company) async {
    try {
      final db = await DatabaseService().database;
      await db.update(
        'companies',
        company.toMap(),
        where: 'id = ?',
        whereArgs: [company.id],
      );

      final index = _companies.indexWhere((c) => c.id == company.id);
      if (index != -1) {
        _companies[index] = company;

        // Update active company if it was updated
        if (_activeCompany?.id == company.id) {
          _activeCompany = company;
        }

        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Error updating company: $e');
      return false;
    }
  }

  // Delete company
  Future<bool> deleteCompany(int companyId) async {
    try {
      final db = await DatabaseService().database;
      await db.delete('companies', where: 'id = ?', whereArgs: [companyId]);

      _companies.removeWhere((c) => c.id == companyId);

      // Set new active company if deleted was active
      if (_activeCompany?.id == companyId) {
        _activeCompany = _companies.isNotEmpty ? _companies.first : null;
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting company: $e');
      return false;
    }
  }

  // Set active company
  Future<void> setActiveCompany(Company company) async {
    _activeCompany = company;
    await _saveActiveCompanyId(company.id);
    notifyListeners();
  }

  // Get company by ID
  Company? getCompanyById(int id) {
    try {
      return _companies.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // Toggle company active status
  Future<bool> toggleCompanyStatus(int companyId) async {
    final company = getCompanyById(companyId);
    if (company == null) return false;

    final updated = company.copyWith(isActive: !company.isActive);
    return await updateCompany(updated);
  }

  // Get active companies count
  int get activeCompaniesCount {
    return _companies.where((c) => c.isActive).length;
  }
}
