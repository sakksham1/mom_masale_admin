import 'user_role.dart';

const Map<String, Set<UserRole>> routePermissions = {
  '/dashboard': {UserRole.admin, UserRole.manager},
  '/orders': {UserRole.admin},
  '/customers': {UserRole.admin},
  '/me': {
    UserRole.admin,
    UserRole.manager,
    UserRole.warehouser,
    UserRole.packaging,
    UserRole.salesperson,
  },
  '/inventory': {UserRole.admin},
  '/packaging': {UserRole.packaging},
  '/packaging/history': {UserRole.packaging},
  '/warehouse': {
    UserRole.warehouser,
    UserRole.packaging,
    UserRole.manager,
    UserRole.admin,
  },
  '/sales': {UserRole.salesperson},
  '/approvals': {UserRole.manager, UserRole.admin},
};

bool canAccessRoute(String path, UserRole role) {
  final allowed = routePermissions[path];
  if (allowed == null) return false;
  return allowed.contains(role);
}
