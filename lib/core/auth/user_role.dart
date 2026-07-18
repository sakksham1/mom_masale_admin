/// Add new roles here as your business grows (e.g. staff, packer, accountant).
/// `unknown` is the safe fallback for any role string the app doesn't
/// recognize yet — it gets zero permissions, never admin-level by default.
enum UserRole {
  admin,
  customer,
  unknown;

  static UserRole fromString(String? value) {
    switch (value) {
      case 'admin':
        return UserRole.admin;
      case 'customer':
        return UserRole.customer;
      default:
        return UserRole.unknown;
    }
  }
}