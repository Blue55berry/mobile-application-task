import 'package:flutter/foundation.dart';
import '../models/quotation_model.dart';
import '../models/quotation_item_model.dart';
import '../services/database_service.dart';

class QuotationService extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  List<Quotation> _quotations = [];
  bool _isLoading = false;

  List<Quotation> get quotations => _quotations;
  bool get isLoading => _isLoading;

  // Load all quotations
  Future<void> loadQuotations() async {
    _isLoading = true;
    notifyListeners();

    try {
      _quotations = await _databaseService.getQuotations();
    } catch (e) {
      debugPrint('Error loading quotations: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get quotations for a specific lead
  Future<List<Quotation>> getQuotationsForLead(int leadId) async {
    return await _databaseService.getQuotationsForLead(leadId);
  }

  // Get quotation by ID
  Future<Quotation?> getQuotationById(int id) async {
    return await _databaseService.getQuotationById(id);
  }

  // Create new quotation with items
  Future<int?> createQuotation({
    required int leadId,
    required DateTime validUntil,
    required List<QuotationItem> items,
    required double taxRate,
    double discountPercent = 0,
    String? notes,
    String? termsAndConditions,
    String status = 'Draft',
  }) async {
    try {
      // Calculate totals
      final subtotal = items.fold<double>(
        0,
        (sum, item) => sum + item.totalPrice,
      );

      final discountAmount = subtotal * (discountPercent / 100);
      final afterDiscount = subtotal - discountAmount;
      final taxAmount = afterDiscount * (taxRate / 100);
      final totalAmount = afterDiscount + taxAmount;

      // Generate quotation number
      final sequence = await _databaseService.getNextQuotationSequence();
      final quotationNumber = Quotation.generateQuotationNumber(sequence);

      // Create quotation
      final quotation = Quotation(
        leadId: leadId,
        quotationNumber: quotationNumber,
        createdAt: DateTime.now(),
        validUntil: validUntil,
        status: status,
        subtotal: subtotal,
        taxRate: taxRate,
        taxAmount: taxAmount,
        discountPercent: discountPercent,
        discountAmount: discountAmount,
        totalAmount: totalAmount,
        notes: notes,
        termsAndConditions: termsAndConditions,
      );

      final quotationId = await _databaseService.insertQuotation(quotation);

      // Insert items
      for (var i = 0; i < items.length; i++) {
        final item = items[i].copyWith(quotationId: quotationId, position: i);
        await _databaseService.insertQuotationItem(item);
      }

      await loadQuotations();
      return quotationId;
    } catch (e) {
      debugPrint('Error creating quotation: $e');
      return null;
    }
  }

  // Update quotation
  Future<bool> updateQuotation({
    required int quotationId,
    required int leadId,
    required DateTime validUntil,
    required List<QuotationItem> items,
    required double taxRate,
    double discountPercent = 0,
    String? notes,
    String? termsAndConditions,
    required String status,
    required String quotationNumber,
    required DateTime createdAt,
  }) async {
    try {
      // Calculate totals
      final subtotal = items.fold<double>(
        0,
        (sum, item) => sum + item.totalPrice,
      );

      final discountAmount = subtotal * (discountPercent / 100);
      final afterDiscount = subtotal - discountAmount;
      final taxAmount = afterDiscount * (taxRate / 100);
      final totalAmount = afterDiscount + taxAmount;

      // Update quotation
      final quotation = Quotation(
        id: quotationId,
        leadId: leadId,
        quotationNumber: quotationNumber,
        createdAt: createdAt,
        validUntil: validUntil,
        status: status,
        subtotal: subtotal,
        taxRate: taxRate,
        taxAmount: taxAmount,
        discountPercent: discountPercent,
        discountAmount: discountAmount,
        totalAmount: totalAmount,
        notes: notes,
        termsAndConditions: termsAndConditions,
      );

      await _databaseService.updateQuotation(quotation);

      // Delete old items and insert new ones
      final oldItems = await _databaseService.getQuotationItems(quotationId);
      for (var oldItem in oldItems) {
        await _databaseService.deleteQuotationItem(oldItem.id!);
      }

      for (var i = 0; i < items.length; i++) {
        final item = items[i].copyWith(quotationId: quotationId, position: i);
        await _databaseService.insertQuotationItem(item);
      }

      await loadQuotations();
      return true;
    } catch (e) {
      debugPrint('Error updating quotation: $e');
      return false;
    }
  }

  // Delete quotation
  Future<bool> deleteQuotation(int id) async {
    try {
      await _databaseService.deleteQuotation(id);
      await loadQuotations();
      return true;
    } catch (e) {
      debugPrint('Error deleting quotation: $e');
      return false;
    }
  }

  // Update quotation status
  Future<bool> updateQuotationStatus(int id, String newStatus) async {
    try {
      final quotation = await _databaseService.getQuotationById(id);
      if (quotation == null) return false;

      final updated = quotation.copyWith(status: newStatus);
      await _databaseService.updateQuotation(updated);
      await loadQuotations();
      return true;
    } catch (e) {
      debugPrint('Error updating quotation status: $e');
      return false;
    }
  }

  // Get items for a quotation
  Future<List<QuotationItem>> getQuotationItems(int quotationId) async {
    return await _databaseService.getQuotationItems(quotationId);
  }

  // Filter quotations by status
  List<Quotation> filterByStatus(String status) {
    if (status == 'All') return _quotations;
    return _quotations.where((q) => q.status == status).toList();
  }

  // Search quotations
  List<Quotation> searchQuotations(String query) {
    if (query.isEmpty) return _quotations;
    return _quotations
        .where(
          (q) => q.quotationNumber.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }
}
