import 'package:intl/intl.dart';

class Invoice {
  final int? id;
  final int leadId;
  final int? quotationId; // nullable - if converted from quotation
  final String invoiceNumber;
  final DateTime createdAt;
  final DateTime dueDate;
  final String status; // Draft, Sent, Paid, Overdue, Cancelled
  final String paymentStatus; // Unpaid, Partial, Paid
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double discountPercent;
  final double discountAmount;
  final double totalAmount;
  final double paidAmount;
  final double balanceAmount;
  final String? notes;
  final String? termsAndConditions;
  final DateTime? paidDate;

  Invoice({
    this.id,
    required this.leadId,
    this.quotationId,
    required this.invoiceNumber,
    required this.createdAt,
    required this.dueDate,
    required this.status,
    required this.paymentStatus,
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    this.discountPercent = 0,
    this.discountAmount = 0,
    required this.totalAmount,
    this.paidAmount = 0,
    required this.balanceAmount,
    this.notes,
    this.termsAndConditions,
    this.paidDate,
  });

  // Generate invoice number: INV-YYYYMMDD-XXX
  static String generateInvoiceNumber(int sequence) {
    final dateString = DateFormat('yyyyMMdd').format(DateTime.now());
    final sequenceString = sequence.toString().padLeft(3, '0');
    return 'INV-$dateString-$sequenceString';
  }

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'leadId': leadId,
      'quotationId': quotationId,
      'invoiceNumber': invoiceNumber,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'status': status,
      'paymentStatus': paymentStatus,
      'subtotal': subtotal,
      'taxRate': taxRate,
      'taxAmount': taxAmount,
      'discountPercent': discountPercent,
      'discountAmount': discountAmount,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'balanceAmount': balanceAmount,
      'notes': notes,
      'termsAndConditions': termsAndConditions,
      'paidDate': paidDate?.toIso8601String(),
    };
  }

  // Create from Map (database)
  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'],
      leadId: map['leadId'],
      quotationId: map['quotationId'],
      invoiceNumber: map['invoiceNumber'],
      createdAt: DateTime.parse(map['createdAt']),
      dueDate: DateTime.parse(map['dueDate']),
      status: map['status'],
      paymentStatus: map['paymentStatus'],
      subtotal: map['subtotal'],
      taxRate: map['taxRate'],
      taxAmount: map['taxAmount'],
      discountPercent: map['discountPercent'] ?? 0,
      discountAmount: map['discountAmount'] ?? 0,
      totalAmount: map['totalAmount'],
      paidAmount: map['paidAmount'] ?? 0,
      balanceAmount: map['balanceAmount'],
      notes: map['notes'],
      termsAndConditions: map['termsAndConditions'],
      paidDate: map['paidDate'] != null
          ? DateTime.parse(map['paidDate'])
          : null,
    );
  }

  // Create a copy with modified fields
  Invoice copyWith({
    int? id,
    int? leadId,
    int? quotationId,
    String? invoiceNumber,
    DateTime? createdAt,
    DateTime? dueDate,
    String? status,
    String? paymentStatus,
    double? subtotal,
    double? taxRate,
    double? taxAmount,
    double? discountPercent,
    double? discountAmount,
    double? totalAmount,
    double? paidAmount,
    double? balanceAmount,
    String? notes,
    String? termsAndConditions,
    DateTime? paidDate,
  }) {
    return Invoice(
      id: id ?? this.id,
      leadId: leadId ?? this.leadId,
      quotationId: quotationId ?? this.quotationId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      subtotal: subtotal ?? this.subtotal,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      balanceAmount: balanceAmount ?? this.balanceAmount,
      notes: notes ?? this.notes,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      paidDate: paidDate ?? this.paidDate,
    );
  }

  // Check if invoice is overdue
  bool isOverdue() {
    return DateTime.now().isAfter(dueDate) && paymentStatus != 'Paid';
  }

  // Get days until/past due
  int getDaysToDue() {
    return dueDate.difference(DateTime.now()).inDays;
  }

  // Get status color
  static String getStatusColor(String status) {
    switch (status) {
      case 'Draft':
        return '#9E9E9E';
      case 'Sent':
        return '#2196F3';
      case 'Paid':
        return '#4CAF50';
      case 'Overdue':
        return '#F44336';
      case 'Cancelled':
        return '#757575';
      default:
        return '#9E9E9E';
    }
  }

  // Get payment status color
  static String getPaymentStatusColor(String paymentStatus) {
    switch (paymentStatus) {
      case 'Unpaid':
        return '#F44336';
      case 'Partial':
        return '#FF9800';
      case 'Paid':
        return '#4CAF50';
      default:
        return '#9E9E9E';
    }
  }
}
