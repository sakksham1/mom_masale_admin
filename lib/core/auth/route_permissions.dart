// lib/core/auth/route_permissions.dart
import 'user_role.dart';

const Map<String, Set<UserRole>> routePermissions = {
  '/dashboard': {UserRole.admin, UserRole.manager},
  '/business': {UserRole.admin},
  '/me': {
    UserRole.admin,
    UserRole.manager,
    UserRole.warehouser,
    UserRole.packaging,
    UserRole.salesperson,
  },
  '/stock': {
    UserRole.admin,
    UserRole.manager,
    UserRole.warehouser,
    UserRole.packaging,
  },
  '/packaging': {UserRole.packaging},
  '/packaging/single': {UserRole.packaging},
  '/packaging/bulk': {UserRole.packaging},
  '/packaging/history': {UserRole.packaging},
  '/sales': {UserRole.salesperson},
  '/approvals': {UserRole.manager, UserRole.admin},
  '/db-explorer': {UserRole.admin},
};

bool canAccessRoute(String path, UserRole role) {
  final allowed = routePermissions[path];
  if (allowed == null) return false;
  return allowed.contains(role);
}
