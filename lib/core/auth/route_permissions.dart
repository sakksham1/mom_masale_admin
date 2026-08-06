// lib/core/auth/route_permissions.dart
import 'user_role.dart';

const Map<String, Set<UserRole>> routePermissions = {
  '/dashboard': {UserRole.admin, UserRole.manager},
  '/business': {UserRole.admin, UserRole.manager},
  '/site': {UserRole.admin, UserRole.manager},
  '/catalog': {UserRole.admin, UserRole.manager},
  '/reviews': {UserRole.admin, UserRole.manager},
  '/analytics': {UserRole.admin, UserRole.manager},
  '/careers': {UserRole.admin, UserRole.manager},
  '/publish-queue': {UserRole.admin},
  '/recipes': {UserRole.admin},
  '/blog': {UserRole.admin},
  '/site-core': {UserRole.admin},
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
  '/sessions': {
    UserRole.admin,
    UserRole.manager,
    UserRole.warehouser,
    UserRole.packaging,
    UserRole.salesperson,
  },
  '/packaging': {UserRole.packaging},
  '/packaging/single': {UserRole.packaging},
  '/packaging/bulk': {UserRole.packaging},
  '/packaging/history': {UserRole.packaging},
  '/sales': {UserRole.salesperson},
  '/approvals': {UserRole.manager, UserRole.admin},
  '/db-explorer': {UserRole.admin},
  '/my-requests': {UserRole.packaging, UserRole.warehouser},
};

bool canAccessRoute(String path, UserRole role) {
  final allowed = routePermissions[path];
  if (allowed == null) return false;
  return allowed.contains(role);
}
