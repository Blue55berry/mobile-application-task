import 'package:flutter/foundation.dart';
import '../models/invoice_model.dart';
import '../models/invoice_item_model.dart';
import '../models/quotation_model.dart';
import '../services/database_service.dart';

class InvoiceService extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  List<Invoice> _invoices = [];
  bool _isLoading = false;

  List<Invoice> get invoices => _invoices;
  bool get isLoading => _isLoading;

  // Load all invoices
  Future<void> loadInvoices() async {
    _isLoading = true;
    notifyListeners();

    try {
      _invoices = await _databaseService.getInvoices();
      // Update overdue status
      for (var invoice in _invoices) {
        if (invoice.isOverdue() && invoice.status != 'Overdue') {
          await updateInvoiceStatus(invoice.id!, 'Overdue');
        }
      }
    } catch (e) {
      debugPrint('Error loading invoices: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get invoices for a specific lead
  Future<List<Invoice>> getInvoicesForLead(int leadId) async {
    return await _databaseService.getInvoicesForLead(leadId);
  }

  // Get invoice by ID
  Future<Invoice?> getInvoiceById(int id) async {
    return await _databaseService.getInvoiceById(id);
  }

  // Create new invoice with items
  Future<int?> createInvoice({
    required int leadId,
    int? quotationId,
    required DateTime dueDate,
    required List<InvoiceItem> items,
    required double taxRate,
    double discountPercent = 0,
    String? notes,
    String? termsAndConditions,
    String status = 'Draft',
    String paymentStatus = 'Unpaid',
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

      // Generate invoice number
      final sequence = await _databaseService.getNextInvoiceSequence();
      final invoiceNumber = Invoice.generateInvoiceNumber(sequence);

      // Create invoice
      final invoice = Invoice(
        leadId: leadId,
        quotationId: quotationId,
        invoiceNumber: invoiceNumber,
        createdAt: DateTime.now(),
        dueDate: dueDate,
        status: status,
        paymentStatus: paymentStatus,
        subtotal: subtotal,
        taxRate: taxRate,
        taxAmount: taxAmount,
        discountPercent: discountPercent,
        discountAmount: discountAmount,
        totalAmount: totalAmount,
        paidAmount: 0,
        balanceAmount: totalAmount,
        notes: notes,
        termsAndConditions: termsAndConditions,
      );

      final invoiceId = await _databaseService.insertInvoice(invoice);

      // Insert items
      for (var i = 0; i < items.length; i++) {
        final item = items[i].copyWith(invoiceId: invoiceId, position: i);
        await _databaseService.insertInvoiceItem(item);
      }

      await loadInvoices();
      return invoiceId;
    } catch (e) {
      debugPrint('Error creating invoice: $e');
      return null;
    }
  }

  // Convert quotation to invoice
  Future<int?> convertQuotationToInvoice({
    required Quotation quotation,
    required List items,
    int daysUntilDue = 30,
  }) async {
    try {
      final dueDate = DateTime.now().add(Duration(days: daysUntilDue));

      // Convert QuotationItems to InvoiceItems
      final invoiceItems = items.map((item) {
        return InvoiceItem(
          invoiceId: 0, // Will be set after invoice creation
          itemName: item.itemName,
          description: item.description,
          quantity: item.quantity,
          unit: item.unit,
          unitPrice: item.unitPrice,
          totalPrice: item.totalPrice,
          position: item.position,
        );
      }).toList();

      final invoiceId = await createInvoice(
        leadId: quotation.leadId,
        quotationId: quotation.id,
        dueDate: dueDate,
        items: invoiceItems,
        taxRate: quotation.taxRate,
        discountPercent: quotation.discountPercent,
        notes: quotation.notes,
        termsAndConditions: quotation.termsAndConditions,
        status: 'Sent',
        paymentStatus: 'Unpaid',
      );

      return invoiceId;
    } catch (e) {
      debugPrint('Error converting quotation to invoice: $e');
      return null;
    }
  }

  // Record payment
  Future<bool> recordPayment(int invoiceId, double amount) async {
    try {
      final invoice = await _databaseService.getInvoiceById(invoiceId);
      if (invoice == null) return false;

      final newPaidAmount = invoice.paidAmount + amount;
      final newBalanceAmount = invoice.totalAmount - newPaidAmount;

      String newPaymentStatus;
      String newStatus;

      if (newBalanceAmount <= 0) {
        newPaymentStatus = 'Paid';
        newStatus = 'Paid';
      } else if (newPaidAmount > 0) {
        newPaymentStatus = 'Partial';
        newStatus = 'Sent';
      } else {
        newPaymentStatus = 'Unpaid';
        newStatus = invoice.status;
      }

      final updated = invoice.copyWith(
        paidAmount: newPaidAmount,
        balanceAmount: newBalanceAmount,
        paymentStatus: newPaymentStatus,
        status: newStatus,
        paidDate: newPaymentStatus == 'Paid' ? DateTime.now() : null,
      );

      await _databaseService.updateInvoice(updated);
      await loadInvoices();
      return true;
    } catch (e) {
      debugPrint('Error recording payment: $e');
      return false;
    }
  }

  // Mark as paid
  Future<bool> markAsPaid(int invoiceId) async {
    try {
      final invoice = await _databaseService.getInvoiceById(invoiceId);
      if (invoice == null) return false;

      return await recordPayment(invoiceId, invoice.balanceAmount);
    } catch (e) {
      debugPrint('Error marking invoice as paid: $e');
      return false;
    }
  }

  // Delete invoice
  Future<bool> deleteInvoice(int id) async {
    try {
      await _databaseService.deleteInvoice(id);
      await loadInvoices();
      return true;
    } catch (e) {
      debugPrint('Error deleting invoice: $e');
      return false;
    }
  }

  // Update invoice status
  Future<bool> updateInvoiceStatus(int id, String newStatus) async {
    try {
      final invoice = await _databaseService.getInvoiceById(id);
      if (invoice == null) return false;

      final updated = invoice.copyWith(status: newStatus);
      await _databaseService.updateInvoice(updated);
      await loadInvoices();
      return true;
    } catch (e) {
      debugPrint('Error updating invoice status: $e');
      return false;
    }
  }

  // Get items for an invoice
  Future<List<InvoiceItem>> getInvoiceItems(int invoiceId) async {
    return await _databaseService.getInvoiceItems(invoiceId);
  }

  // Filter invoices
  List<Invoice> filterByStatus(String status) {
    if (status == 'All') return _invoices;
    return _invoices.where((inv) => inv.status == status).toList();
  }

  List<Invoice> filterByPaymentStatus(String paymentStatus) {
    if (paymentStatus == 'All') return _invoices;
    return _invoices
        .where((inv) => inv.paymentStatus == paymentStatus)
        .toList();
  }

  // Get overdue invoices
  List<Invoice> getOverdueInvoices() {
    return _invoices.where((inv) => inv.isOverdue()).toList();
  }

  // Search invoices
  List<Invoice> searchInvoices(String query) {
    if (query.isEmpty) return _invoices;
    return _invoices
        .where(
          (inv) =>
              inv.invoiceNumber.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  // Get total revenue (all paid invoices)
  double getTotalRevenue() {
    return _invoices
        .where((inv) => inv.paymentStatus == 'Paid')
        .fold<double>(0, (sum, inv) => sum + inv.totalAmount);
  }

  // Get pending revenue (unpaid + partial)
  double getPendingRevenue() {
    return _invoices
        .where((inv) => inv.paymentStatus != 'Paid')
        .fold<double>(0, (sum, inv) => sum + inv.balanceAmount);
  }
}
