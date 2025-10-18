enum UserRole { admin, staff }

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  const AppUser({required this.id, required this.name, required this.email, required this.role});

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: UserRole.values.firstWhere((e) => e.toString() == 'UserRole.${json['role']}'),
    );
  }
}
