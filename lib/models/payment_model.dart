class Payment {
  int? id;
  int invoiceId;
  double amount;
  DateTime paymentDate;
  String paymentMethod; // Cash, Bank Transfer, UPI, Cheque, Card, etc.
  String? referenceNumber; // Transaction ID, Cheque number, etc.
  String? notes;

  Payment({
    this.id,
    required this.invoiceId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    this.referenceNumber,
    this.notes,
  });

  // Convert to Map for database insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'payment_method': paymentMethod,
      'reference_number': referenceNumber,
      'notes': notes,
    };
  }

  // Create from database Map
  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      invoiceId: map['invoice_id'],
      amount: map['amount'],
      paymentDate: DateTime.parse(map['payment_date']),
      paymentMethod: map['payment_method'],
      referenceNumber: map['reference_number'],
      notes: map['notes'],
    );
  }

  // Common payment methods
  static const List<String> paymentMethods = [
    'Cash',
    'Bank Transfer',
    'UPI',
    'Cheque',
    'Credit Card',
    'Debit Card',
    'Net Banking',
    'Other',
  ];
}
