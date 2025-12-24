import 'package:intl/intl.dart';

class Quotation {
  final int? id;
  final int leadId;
  final String quotationNumber;
  final DateTime createdAt;
  final DateTime validUntil;
  final String status; // Draft, Sent, Accepted, Rejected, Converted
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double discountPercent;
  final double discountAmount;
  final double totalAmount;
  final String? notes;
  final String? termsAndConditions;

  Quotation({
    this.id,
    required this.leadId,
    required this.quotationNumber,
    required this.createdAt,
    required this.validUntil,
    required this.status,
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    this.discountPercent = 0,
    this.discountAmount = 0,
    required this.totalAmount,
    this.notes,
    this.termsAndConditions,
  });

  // Generate quotation number: QT-YYYYMMDD-XXX
  static String generateQuotationNumber(int sequence) {
    final dateString = DateFormat('yyyyMMdd').format(DateTime.now());
    final sequenceString = sequence.toString().padLeft(3, '0');
    return 'QT-$dateString-$sequenceString';
  }

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'leadId': leadId,
      'quotationNumber': quotationNumber,
      'createdAt': createdAt.toIso8601String(),
      'validUntil': validUntil.toIso8601String(),
      'status': status,
      'subtotal': subtotal,
      'taxRate': taxRate,
      'taxAmount': taxAmount,
      'discountPercent': discountPercent,
      'discountAmount': discountAmount,
      'totalAmount': totalAmount,
      'notes': notes,
      'termsAndConditions': termsAndConditions,
    };
  }

  // Create from Map (database)
  factory Quotation.fromMap(Map<String, dynamic> map) {
    return Quotation(
      id: map['id'],
      leadId: map['leadId'],
      quotationNumber: map['quotationNumber'],
      createdAt: DateTime.parse(map['createdAt']),
      validUntil: DateTime.parse(map['validUntil']),
      status: map['status'],
      subtotal: map['subtotal'],
      taxRate: map['taxRate'],
      taxAmount: map['taxAmount'],
      discountPercent: map['discountPercent'] ?? 0,
      discountAmount: map['discountAmount'] ?? 0,
      totalAmount: map['totalAmount'],
      notes: map['notes'],
      termsAndConditions: map['termsAndConditions'],
    );
  }

  // Create a copy with modified fields
  Quotation copyWith({
    int? id,
    int? leadId,
    String? quotationNumber,
    DateTime? createdAt,
    DateTime? validUntil,
    String? status,
    double? subtotal,
    double? taxRate,
    double? taxAmount,
    double? discountPercent,
    double? discountAmount,
    double? totalAmount,
    String? notes,
    String? termsAndConditions,
  }) {
    return Quotation(
      id: id ?? this.id,
      leadId: leadId ?? this.leadId,
      quotationNumber: quotationNumber ?? this.quotationNumber,
      createdAt: createdAt ?? this.createdAt,
      validUntil: validUntil ?? this.validUntil,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      notes: notes ?? this.notes,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
    );
  }

  // Check if quotation is expired
  bool isExpired() {
    return DateTime.now().isAfter(validUntil);
  }

  // Get status color
  static String getStatusColor(String status) {
    switch (status) {
      case 'Draft':
        return '#9E9E9E';
      case 'Sent':
        return '#2196F3';
      case 'Accepted':
        return '#4CAF50';
      case 'Rejected':
        return '#F44336';
      case 'Converted':
        return '#6C5CE7';
      default:
        return '#9E9E9E';
    }
  }
}
