class Worker {
  final String id;
  final String name;
  final String phoneNumber;
  final String? address;
  final String? notes;
  final DateTime joinedDate;
  final bool isActive;

  const Worker({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.address,
    this.notes,
    required this.joinedDate,
    this.isActive = true,
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
    };
  }

  factory Worker.fromJson(Map<String, dynamic> json) {
    return Worker(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      address: json['address'],
      notes: json['notes'],
      joinedDate: DateTime.parse(json['joinedDate']),
      isActive: json['isActive'] ?? true,
    );
  }
}
