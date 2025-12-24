class QuotationItem {
  final int? id;
  final int quotationId;
  final String itemName;
  final String? description;
  final double quantity;
  final String unit; // pcs, hours, days, kg, etc.
  final double unitPrice;
  final double totalPrice; // quantity * unitPrice
  final int position; // for ordering items

  QuotationItem({
    this.id,
    required this.quotationId,
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
      'quotationId': quotationId,
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
  factory QuotationItem.fromMap(Map<String, dynamic> map) {
    return QuotationItem(
      id: map['id'],
      quotationId: map['quotationId'],
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
  QuotationItem copyWith({
    int? id,
    int? quotationId,
    String? itemName,
    String? description,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? totalPrice,
    int? position,
  }) {
    return QuotationItem(
      id: id ?? this.id,
      quotationId: quotationId ?? this.quotationId,
      itemName: itemName ?? this.itemName,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      position: position ?? this.position,
    );
  }

  // Common units
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
