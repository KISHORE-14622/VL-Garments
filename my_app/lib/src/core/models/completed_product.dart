class CompletedProduct {
  final String id;
  final DateTime date;
  final int quantity;
  final double sellingRate;
  final double costPerUnit;
  final String brandName;
  final String notes;
  final String invoiceNumber;

  CompletedProduct({
    required this.id,
    required this.date,
    required this.quantity,
    required this.sellingRate,
    required this.costPerUnit,
    this.brandName = '',
    this.notes = '',
    this.invoiceNumber = '',
  });

  factory CompletedProduct.fromJson(Map<String, dynamic> json) {
    return CompletedProduct(
      id: json['_id'] as String,
      date: DateTime.parse(json['date'] as String),
      quantity: json['quantity'] as int,
      sellingRate: (json['sellingRate'] as num).toDouble(),
      costPerUnit: (json['costPerUnit'] as num).toDouble(),
      brandName: json['brandName'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'quantity': quantity,
      'sellingRate': sellingRate,
      'costPerUnit': costPerUnit,
      'brandName': brandName,
      'notes': notes,
    };
  }

  double get totalRevenue => quantity * sellingRate;
  double get totalCost => quantity * costPerUnit;
  double get profit => totalRevenue - totalCost;
}
