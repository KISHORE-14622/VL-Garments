class InventoryItem {
  final String id;
  final String name;
  final int quantity;
  final double unitCost;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitCost,
  });

  double get totalCost => unitCost * quantity;
}


