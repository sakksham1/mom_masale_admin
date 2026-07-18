import 'user_role.dart';

/// Declares which roles may access which top-level routes.
/// Add a route here the moment it's role-restricted; anything not listed
/// is treated as admin-only by default (fail closed, not open).
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