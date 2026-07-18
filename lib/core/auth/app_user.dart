import 'user_role.dart';

class AppUser {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final UserRole role;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'],
    name: j['name'],
    email: j['email'],
    phone: j['phone'],
    role: UserRole.fromString(j['role'] as String?),
  );
}