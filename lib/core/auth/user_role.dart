/// Mirrors the `role` column in D1 — the single source of truth for access
/// control on both the backend (see functions/api/_utils/admin.js) and here.
/// `unknown` is the safe fallback for any role string the app doesn't
/// recognize yet — it gets zero permissions, never admin-level by default.
///
/// staff/packer/accountant are declared ahead of use: no routes grant them
/// anything yet (see route_permissions.dart, which fails closed for anything
/// unlisted), but the enum exists so adding a role to a route later is a
/// one-line change instead of a refactor.
enum UserRole {
  admin,
  staff,
  packer,
  accountant,
  customer,
  unknown;

  static UserRole fromString(String? value) {
    switch (value) {
      case 'admin':
        return UserRole.admin;
      case 'staff':
        return UserRole.staff;
      case 'packer':
        return UserRole.packer;
      case 'accountant':
        return UserRole.accountant;
      case 'customer':
        return UserRole.customer;
      default:
        return UserRole.unknown;
    }
  }
}
