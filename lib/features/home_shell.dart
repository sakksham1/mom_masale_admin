import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';

class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  static const _tabs = ['/dashboard', '/orders', '/customers'];

  int _indexForLocation(String location) {
    final i = _tabs.indexWhere((t) => location.startsWith(t));
    return i == -1 ? 0 : i;
  }

  bool _onAccountPage(String location) => location.startsWith('/me');

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final scheme = Theme.of(context).colorScheme;
    final onAccount = _onAccountPage(location);
    final selectedIndex = onAccount ? -1 : _indexForLocation(location);

    return Scaffold(
      // No bottomNavigationBar here — Scaffold paints an opaque Material
      // behind that slot regardless of what you give it, which is what was
      // blocking the content. Instead the bar is a Positioned overlay in
      // this Stack, so the page content genuinely runs underneath it.
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
                selectedIndex: selectedIndex,
                onAccount: onAccount,
                scheme: scheme,
                onTabTap: (i) => context.go(_tabs[i]),
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
  final int selectedIndex;
  final bool onAccount;
  final ColorScheme scheme;
  final ValueChanged<int> onTabTap;
  final VoidCallback onAccountTap;

  const _FloatingNavBar({
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
        // The blur is what makes content behind the bar read as "frosted
        // glass" rather than a flat translucent rectangle.
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
                    _NavIcon(
                      icon: Icons.dashboard_outlined,
                      selectedIcon: Icons.dashboard,
                      label: 'Overview',
                      selected: selectedIndex == 0,
                      onTap: () => onTabTap(0),
                    ),
                    _NavIcon(
                      icon: Icons.receipt_long_outlined,
                      selectedIcon: Icons.receipt_long,
                      label: 'Orders',
                      selected: selectedIndex == 1,
                      onTap: () => onTabTap(1),
                    ),
                    _NavIcon(
                      icon: Icons.people_outline,
                      selectedIcon: Icons.people,
                      label: 'Customers',
                      selected: selectedIndex == 2,
                      onTap: () => onTabTap(2),
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
