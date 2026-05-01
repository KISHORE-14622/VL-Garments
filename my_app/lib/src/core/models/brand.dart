class Brand {
  final String id;
  final String name;
  final double sellingRate;
  final double costPerUnit;

  Brand({
    required this.id,
    required this.name,
    required this.sellingRate,
    required this.costPerUnit,
  });

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      id: json['_id'] as String,
      name: json['name'] as String,
      sellingRate: (json['sellingRate'] as num).toDouble(),
      costPerUnit: (json['costPerUnit'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sellingRate': sellingRate,
      'costPerUnit': costPerUnit,
    };
  }
}
