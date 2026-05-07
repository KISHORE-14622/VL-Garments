class InventoryType {
  final String id;
  final String name;

  InventoryType({
    required this.id,
    required this.name,
  });

  factory InventoryType.fromJson(Map<String, dynamic> json) {
    return InventoryType(
      id: json['_id'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
    };
  }
}
