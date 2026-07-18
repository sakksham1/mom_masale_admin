import 'package:go_router/go_router.dart';
import '../auth/auth_controller.dart';
import '../auth/route_permissions.dart';
import '../../features/auth/login_screen.dart';
import '../../features/home_shell.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/orders/orders_list_screen.dart';
import '../../features/customers/customers_list_screen.dart';

GoRouter buildRouter(AuthController auth) {
  return GoRouter(
    refreshListenable: auth,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      if (auth.initializing) return null; // splash handles this state

      final loggedIn = auth.isLoggedIn;
      final loggingIn = state.matchedLocation == '/login';

      if (!loggedIn && !loggingIn) return '/login';
      if (loggedIn && loggingIn) return '/dashboard';

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
          GoRoute(path: '/dashboard', builder: (c, s) => const DashboardScreen()),
          GoRoute(path: '/orders', builder: (c, s) => const OrdersListScreen()),
          GoRoute(path: '/customers', builder: (c, s) => const CustomersListScreen()),
        ],
      ),
    ],
  );
}