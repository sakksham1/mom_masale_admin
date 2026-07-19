import 'user_role.dart';

/// Declares which roles may access which top-level routes.
/// Add a route here the moment it's role-restricted; anything not listed
/// is treated as admin-only by default (fail closed, not open).
///
/// UserRole now includes staff/packer/accountant (see user_role.dart) for
/// future screens — none are granted access to anything below yet. Add them
/// to the relevant route's set when that screen ships, e.g.:
///   '/orders': {UserRole.admin, UserRole.packer},
const Map<String, Set<UserRole>> routePermissions = {
  '/dashboard': {UserRole.admin},
  '/orders': {UserRole.admin},
  '/customers': {UserRole.admin},
};

bool canAccessRoute(String path, UserRole role) {
  final allowed = routePermissions[path];
  if (allowed == null) return false; // fail closed for unlisted routes
  return allowed.contains(role);
}
