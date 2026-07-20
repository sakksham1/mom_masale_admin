import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/auth/route_permissions.dart';
import '../core/network/api_client_provider.dart';

class _NavItem {
  final String path;
  final IconData icon, selectedIcon;
  final String label;
  const _NavItem(this.path, this.icon, this.selectedIcon, this.label);
}

const _allNavItems = [
  _NavItem('/dashboard', Icons.dashboard_outlined, Icons.dashboard, 'Overview'),
  _NavItem(
    '/orders',
    Icons.receipt_long_outlined,
    Icons.receipt_long,
    'Orders',
  ),
  _NavItem('/customers', Icons.people_outline, Icons.people, 'Customers'),
  _NavItem(
    '/inventory',
    Icons.inventory_2_outlined,
    Icons.inventory_2,
    'Inventory',
  ),
  _NavItem(
    '/warehouse',
    Icons.warehouse_outlined,
    Icons.warehouse,
    'Warehouse',
  ),
  _NavItem(
    '/sales',
    Icons.point_of_sale_outlined,
    Icons.point_of_sale,
    'Sales',
  ),
  _NavItem(
    '/approvals',
    Icons.fact_check_outlined,
    Icons.fact_check,
    'Approvals',
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

    // Only show tabs this role is actually permitted to open — avoids the
    // "tap a tab, get silently bounced to /login?denied=1" trap.
    final tabs = _allNavItems
        .where((i) => canAccessRoute(i.path, role))
        .toList();

    final onAccount = _onAccountPage(location);
    final selectedIndex = onAccount
        ? -1
        : tabs.indexWhere((t) => location.startsWith(t.path));

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: _FloatingNavBar(
                tabs: tabs,
                selectedIndex: selectedIndex,
                onAccount: onAccount,
                scheme: scheme,
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
  final ValueChanged<int> onTabTap;
  final VoidCallback onAccountTap;

  const _FloatingNavBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onAccount,
    required this.scheme,
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
          height: 64,
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
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = false,
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
            Icon(selected ? selectedIcon : icon, color: color, size: 24),
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
