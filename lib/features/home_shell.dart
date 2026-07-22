// lib/features/home_shell.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/auth/route_permissions.dart';
import '../core/network/api_client_provider.dart';
import '../core/constants/layout_constants.dart';
import '../features/approvals/approvals_provider.dart';
import '../shared/widgets/app_banner.dart';

class _NavItem {
  final String path;
  final IconData icon, selectedIcon;
  final String label;
  const _NavItem(this.path, this.icon, this.selectedIcon, this.label);
}

// Consolidated: each entry may represent multiple merged screens (e.g.
// "Business" = Orders + Customers, "Stock" = Inventory + Warehouse) so the
// nav never overflows regardless of how many permissions a role has.
const _allNavItems = [
  _NavItem('/dashboard', Icons.dashboard_outlined, Icons.dashboard, 'Overview'),
  _NavItem(
    '/business',
    Icons.storefront_outlined,
    Icons.storefront,
    'Business',
  ),
  _NavItem(
    '/stock',
    Icons.inventory_2_outlined,
    Icons.inventory_2,
    'Inventory',
  ),
  _NavItem('/catalog', Icons.category_outlined, Icons.category, 'Catalog'),
  _NavItem(
    '/approvals',
    Icons.fact_check_outlined,
    Icons.fact_check,
    'Approvals',
  ),
  _NavItem(
    '/sales',
    Icons.point_of_sale_outlined,
    Icons.point_of_sale,
    'Sales',
  ),
  _NavItem(
    '/packaging',
    Icons.inventory_outlined,
    Icons.inventory,
    'Packaging',
  ),
];

class HomeShell extends ConsumerWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  bool _onAccountPage(String location) => location.startsWith('/me');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final scheme = Theme.of(context).colorScheme;
    final role = ref.watch(authControllerProvider).role;

    final tabs = _allNavItems
        .where((i) => canAccessRoute(i.path, role))
        .toList();

    final onAccount = _onAccountPage(location);
    final selectedIndex = onAccount
        ? -1
        : tabs.indexWhere((t) => location.startsWith(t.path));

    // Only watch the approvals queue if the role can even see that tab —
    // no point polling it for roles (packaging, warehouser, salesperson)
    // who never see the Approvals nav item at all.
    final canSeeApprovals = tabs.any((t) => t.path == '/approvals');
    final hasPendingApprovals = canSeeApprovals
        ? ref
              .watch(approvalsQueueProvider)
              .maybeWhen(data: (q) => !q.isEmpty, orElse: () => false)
        : false;

    return Scaffold(
      appBar: const AppBanner(),
      body: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: 20,
            right: 20,
            bottom: LayoutConstants.navBarBottomMargin,
            child: SafeArea(
              top: false,
              child: _FloatingNavBar(
                tabs: tabs,
                selectedIndex: selectedIndex,
                onAccount: onAccount,
                scheme: scheme,
                showApprovalsDot: hasPendingApprovals,
                onTabTap: (i) => context.go(tabs[i].path),
                onAccountTap: () => context.go('/me'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final List<_NavItem> tabs;
  final int selectedIndex;
  final bool onAccount;
  final ColorScheme scheme;
  final bool showApprovalsDot;
  final ValueChanged<int> onTabTap;
  final VoidCallback onAccountTap;

  const _FloatingNavBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onAccount,
    required this.scheme,
    required this.showApprovalsDot,
    required this.onTabTap,
    required this.onAccountTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: LayoutConstants.navBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      _NavIcon(
                        icon: tabs[i].icon,
                        selectedIcon: tabs[i].selectedIcon,
                        label: tabs[i].label,
                        selected: selectedIndex == i,
                        showDot:
                            tabs[i].path == '/approvals' && showApprovalsDot,
                        onTap: () => onTabTap(i),
                      ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: scheme.outlineVariant,
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
              _NavIcon(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: 'Me',
                selected: onAccount,
                onTap: onAccountTap,
                accent: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon, selectedIcon;
  final String label;
  final bool selected;
  final bool accent;
  final bool showDot;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = false,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected
        ? (accent ? AppColors.turmeric : scheme.primary)
        : scheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(selected ? selectedIcon : icon, color: color, size: 24),
                if (showDot)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC62828),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.surfaceContainerHigh,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
