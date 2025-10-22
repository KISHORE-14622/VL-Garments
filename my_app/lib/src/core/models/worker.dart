import 'worker_category.dart';

class Worker {
  final String id;
  final String name;
  final String phoneNumber;
  final String? email;
  final String? address;
  final String? notes;
  final DateTime joinedDate;
  final bool isActive;
  final WorkerCategory? category;

  const Worker({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.address,
    this.notes,
    required this.joinedDate,
    this.isActive = true,
    this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'address': address,
      'notes': notes,
      'joinedDate': joinedDate.toIso8601String(),
      'isActive': isActive,
      if (category != null) 'category': category!.id,
    };
  }

  factory Worker.fromJson(Map<String, dynamic> json) {
    WorkerCategory? cat;
    final rawCat = json['category'];
    if (rawCat != null) {
      if (rawCat is Map<String, dynamic>) {
        cat = WorkerCategory.fromJson(rawCat);
      } else {
        cat = WorkerCategory(id: rawCat.toString(), name: rawCat.toString());
      }
    }
    return Worker(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      address: json['address'],
      notes: json['notes'],
      joinedDate: DateTime.parse(json['joinedDate']),
      isActive: json['isActive'] ?? true,
      category: cat,
    );
  }
}
