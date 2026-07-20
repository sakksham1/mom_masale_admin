import 'package:go_router/go_router.dart';
import '../auth/auth_controller.dart';
import '../auth/route_permissions.dart';
import '../auth/login_screen.dart';
import '../../features/home_shell.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/orders/orders_list_screen.dart';
import '../../features/warehouse/warehouse_screen.dart';
import '../../features/sales/sales_screen.dart';
import '../../features/approvals/approvals_screen.dart';
import '../../features/customers/customers_list_screen.dart';
import '../../features/account/account_screen.dart';
import '../../features/products/products_list_screen.dart';
import '../auth/user_role.dart';
import '../../features/packaging/packaging_submit_screen.dart';
import '../../features/packaging/packaging_history_screen.dart';

GoRouter buildRouter(AuthController auth) {
  return GoRouter(
    refreshListenable: auth,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      if (auth.initializing) return null; // splash handles this state

      final loggedIn = auth.isLoggedIn;
      final loggingIn = state.matchedLocation == '/login';
      // NEW: not logged in and not already heading to /login — send them there.
      if (!loggedIn && !loggingIn) {
        return '/login';
      }

      if (loggedIn && loggingIn) {
        switch (auth.role) {
          case UserRole.packaging:
            return '/packaging';
          case UserRole.salesperson:
            return '/sales';
          case UserRole.warehouser:
            return '/warehouse';
          default:
            return '/dashboard';
        }
      }

      if (loggedIn && !canAccessRoute(state.matchedLocation, auth.role)) {
        // Logged in but this role isn't permitted here — bounce to login
        // with an explanation rather than silently failing.
        return '/login?denied=1';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (c, s) => const DashboardScreen(),
          ),
          GoRoute(path: '/orders', builder: (c, s) => const OrdersListScreen()),
          GoRoute(
            path: '/customers',
            builder: (c, s) => const CustomersListScreen(),
          ),
          GoRoute(path: '/me', builder: (c, s) => const AccountScreen()),
          GoRoute(
            path: '/inventory',
            builder: (c, s) => const ProductsListScreen(),
          ),
          GoRoute(
            path: '/packaging',
            builder: (c, s) => const PackagingSubmitScreen(),
          ),
          GoRoute(
            path: '/packaging/history',
            builder: (c, s) => const PackagingHistoryScreen(),
          ),
          GoRoute(
            path: '/packaging/history',
            builder: (c, s) => const PackagingHistoryScreen(),
          ),
          GoRoute(
            path: '/warehouse',
            builder: (c, s) => const WarehouseScreen(),
          ),
          GoRoute(path: '/sales', builder: (c, s) => const SalesScreen()),
          GoRoute(
            path: '/approvals',
            builder: (c, s) => const ApprovalsScreen(),
          ),
        ],
      ),
    ],
  );
}
