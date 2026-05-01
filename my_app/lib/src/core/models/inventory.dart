class InventoryItem {
  final String id;
  final String name;
  final int quantity;
  final double unitCost;
  final double cgstPercent;
  final double sgstPercent;
  final String supplier;
  final DateTime? date;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitCost,
    this.cgstPercent = 0,
    this.sgstPercent = 0,
    this.supplier = '',
    this.date,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0,
      cgstPercent: (json['cgstPercent'] as num?)?.toDouble() ?? 0,
      sgstPercent: (json['sgstPercent'] as num?)?.toDouble() ?? 0,
      supplier: json['supplier'] as String? ?? '',
      date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) : null,
    );
  }

  double get totalCost => unitCost * quantity;
  double get cgstAmount => (totalCost * cgstPercent) / 100;
  double get sgstAmount => (totalCost * sgstPercent) / 100;
  double get totalGst => cgstAmount + sgstAmount;
  double get grandTotal => totalCost + totalGst;
}
