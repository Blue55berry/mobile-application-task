class InvoiceItem {
  final int? id;
  final int invoiceId;
  final String itemName;
  final String? description;
  final double quantity;
  final String unit; // pcs, hours, days, kg, etc.
  final double unitPrice;
  final double totalPrice; // quantity * unitPrice
  final int position; // for ordering items

  InvoiceItem({
    this.id,
    required this.invoiceId,
    required this.itemName,
    this.description,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
    required this.position,
  });

  // Calculate total price
  static double calculateTotalPrice(double quantity, double unitPrice) {
    return quantity * unitPrice;
  }

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'itemName': itemName,
      'description': description,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'position': position,
    };
  }

  // Create from Map (database)
  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'],
      invoiceId: map['invoiceId'],
      itemName: map['itemName'],
      description: map['description'],
      quantity: map['quantity'],
      unit: map['unit'],
      unitPrice: map['unitPrice'],
      totalPrice: map['totalPrice'],
      position: map['position'],
    );
  }

  // Create a copy with modified fields
  InvoiceItem copyWith({
    int? id,
    int? invoiceId,
    String? itemName,
    String? description,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? totalPrice,
    int? position,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      itemName: itemName ?? this.itemName,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      position: position ?? this.position,
    );
  }

  // Common units (same as QuotationItem)
  static const List<String> commonUnits = [
    'pcs',
    'hours',
    'days',
    'kg',
    'grams',
    'liters',
    'meters',
    'sq.ft',
    'set',
    'box',
  ];
}
