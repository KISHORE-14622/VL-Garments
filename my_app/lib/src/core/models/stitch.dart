class StitchEntry {
  final String id;
  final String workerId; // Reference to Worker, not Staff
  final String categoryId; // e.g., shirt, pant
  final int quantity;
  final DateTime date; // entry date

  const StitchEntry({
    required this.id,
    required this.workerId,
    required this.categoryId,
    required this.quantity,
    required this.date,
  });
}


