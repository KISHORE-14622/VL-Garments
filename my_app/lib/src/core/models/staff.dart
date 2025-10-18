class Staff {
  final String id;
  final String name;
  final String phoneNumber;
  final String? email;
  final DateTime joinedDate;
  final bool isActive;

  const Staff({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email,
    required this.joinedDate,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'joinedDate': joinedDate.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'],
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      joinedDate: DateTime.parse(json['joinedDate']),
      isActive: json['isActive'] ?? true,
    );
  }
}
