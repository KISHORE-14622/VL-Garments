class WorkerCategory {
  final String id;
  final String name;
  final bool isActive;

  const WorkerCategory({
    required this.id,
    required this.name,
    this.isActive = true,
  });

  factory WorkerCategory.fromJson(Map<String, dynamic> json) {
    return WorkerCategory(
      id: (json['_id'] ?? json['id']).toString(),
      name: (json['name'] ?? '').toString(),
      isActive: (json['isActive'] ?? true) == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isActive': isActive,
    };
  }
}
