// lib/core/router/app_router.dart
import 'package:go_router/go_router.dart';
import '../auth/auth_controller.dart';
import '../auth/route_permissions.dart';
import '../auth/login_screen.dart';
import '../../features/home_shell.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/business/business_screen.dart';
import '../../features/stock/stock_screen.dart';
import '../../features/sales/sales_screen.dart';
import '../../features/approvals/approvals_screen.dart';
import '../../features/account/account_screen.dart';
import '../auth/user_role.dart';
import '../../features/packaging/packaging_submit_screen.dart';
import '../../features/packaging/packaging_history_screen.dart';
import '../../features/packaging/packaging_mode_select_screen.dart';
import '../../features/packaging/packaging_bulk_report_screen.dart';
import '../../features/db_explorer/db_explorer_screen.dart';
import '../../features/catalog/catalog_list_screen.dart';
import '../../features/sessions/sessions_screen.dart';
import '../../features/reviews/reviews_screen.dart';
import '../../features/analytics/analytics_screen.dart';
import '../../features/requests/my_requests_screen.dart';
import '../../features/onboarding/pending_approval_screen.dart';
import '../../features/onboarding/verify_email_screen.dart';
import '../auth/signup_screen.dart';
import '../../features/publish_queue/publish_queue_screen.dart';
import '../../features/careers/careers_screen.dart';

GoRouter buildRouter(AuthController auth) {
  return GoRouter(
    refreshListenable: auth,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      if (auth.initializing) return null;

      final loggedIn = auth.isLoggedIn;
      final loc = state.matchedLocation;
      final onAuthScreen = loc == '/login' || loc == '/signup';
      final onVerify = loc == '/verify-email';
      final onPending = loc == '/pending-approval';

      if (!loggedIn) {
        return onAuthScreen ? null : '/login';
      }

      // Unverified email — hold here regardless of role, including admins,
      // since verify-email.js is what flips emailVerified for anyone.
      if (!auth.emailVerified) {
        return onVerify ? null : '/verify-email';
      }

      // Verified but still role=customer — a fresh (or demoted) app account
      // waiting for an admin to assign a role.
      if (auth.role == UserRole.customer) {
        return onPending ? null : '/pending-approval';
      }

      if (onAuthScreen || onVerify || onPending) {
        switch (auth.role) {
          case UserRole.packaging:
            return '/packaging';
          case UserRole.salesperson:
            return '/sales';
          case UserRole.warehouser:
            return '/stock';
          default:
            return '/dashboard';
        }
      }

      if (!canAccessRoute(loc, auth.role)) {
        return '/login?denied=1';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (c, s) => const SignupScreen()),
      GoRoute(
        path: '/verify-email',
        builder: (c, s) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/pending-approval',
        builder: (c, s) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: '/packaging/single',
        builder: (c, s) => const PackagingSubmitScreen(),
      ),
      GoRoute(
        path: '/packaging/bulk',
        builder: (c, s) => const PackagingBulkReportScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (c, s) => const DashboardScreen(),
          ),
          GoRoute(path: '/business', builder: (c, s) => const BusinessScreen()),
          GoRoute(path: '/me', builder: (c, s) => const AccountScreen()),
          GoRoute(path: '/stock', builder: (c, s) => const StockScreen()),
          GoRoute(
            path: '/packaging',
            builder: (c, s) => const PackagingModeSelectScreen(),
          ),
          GoRoute(
            path: '/packaging/history',
            builder: (c, s) => const PackagingHistoryScreen(),
          ),
          GoRoute(path: '/sales', builder: (c, s) => const SalesScreen()),
          GoRoute(path: '/catalog', builder: (c, s) => const CatalogScreen()),
          GoRoute(path: '/catalog', builder: (c, s) => const CatalogScreen()),
          GoRoute(path: '/reviews', builder: (c, s) => const ReviewsScreen()),
          GoRoute(
            path: '/analytics',
            builder: (c, s) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (c, s) => const AnalyticsScreen(),
          ),
          GoRoute(path: '/careers', builder: (c, s) => const CareersScreen()),
          GoRoute(
            path: '/publish-queue',
            builder: (c, s) => const PublishQueueScreen(),
          ),
          GoRoute(
            path: '/approvals',
            builder: (c, s) => const ApprovalsScreen(),
          ),
          GoRoute(
            path: '/db-explorer',
            builder: (c, s) => const DbExplorerScreen(),
          ),
          GoRoute(path: '/sessions', builder: (c, s) => const SessionsScreen()),
          GoRoute(
            path: '/my-requests',
            builder: (c, s) => const MyRequestsScreen(),
          ),
        ],
      ),
    ],
  );
}
