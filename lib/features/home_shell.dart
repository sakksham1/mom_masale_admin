// lib/features/home_shell.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/auth/route_permissions.dart';
import '../core/auth/user_role.dart';
import '../core/network/api_client_provider.dart';
import '../core/constants/layout_constants.dart';
import '../features/approvals/approvals_provider.dart';
import '../features/reviews/reviews_provider.dart';
import '../features/publish_queue/publish_queue_provider.dart';
import '../shared/widgets/app_banner.dart';
import '../shared/widgets/nav_more_sheet.dart';

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
  _NavItem('/my-requests', Icons.list_alt_outlined, Icons.list_alt, 'Requests'),
];

/// The "Site" popup's contents — Catalog / Reviews / Publish Queue /
/// Analytics. Not part of _allNavItems since these never render as direct
/// tabs; they only ever appear inside the Site popup. Filtered per-role via
/// canAccessRoute same as everything else (publish-queue is admin-only, so
/// a manager simply never sees that entry).
const _siteNavItems = [
  _NavItem('/catalog', Icons.category_outlined, Icons.category, 'Catalog'),
  _NavItem(
    '/reviews',
    Icons.rate_review_outlined,
    Icons.rate_review,
    'Reviews',
  ),
  _NavItem(
    '/publish-queue',
    Icons.publish_outlined,
    Icons.publish,
    'Publish Queue',
  ),
  _NavItem(
    '/analytics',
    Icons.query_stats_outlined,
    Icons.query_stats,
    'Analytics',
  ),
];

/// Roles whose tab count is congested enough to warrant folding a few
/// sections behind a "More" popup instead of showing every icon directly.
const _moreGroupedRoles = {UserRole.admin, UserRole.manager};

/// Paths folded behind the "More" popup for roles in [_moreGroupedRoles].
const _groupedPaths = {'/business', '/stock', '/approvals'};

sealed class _NavSlot {
  const _NavSlot();
}

class _SingleSlot extends _NavSlot {
  final _NavItem item;
  const _SingleSlot(this.item);
}

/// A popup slot — tapping it opens NavMoreSheet with [items] instead of
/// navigating directly. Used for both "More" (business/stock/approvals)
/// and "Site" (catalog/reviews/publish-queue/analytics).
class _PopupSlot extends _NavSlot {
  final String key;
  final String label;
  final IconData icon, selectedIcon;
  final List<_NavItem> items;
  const _PopupSlot({
    required this.key,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.items,
  });
}

/// Turns the role's accessible tabs into render slots — either a direct
/// icon, or (for grouped roles, when there are enough grouped tabs to be
/// worth folding) a single "More" popup slot standing in for several of
/// them, inserted where the first grouped tab would have been. A "Site"
/// popup slot is appended after, if the role can access any site item.
List<_NavSlot> _buildSlots(List<_NavItem> tabs, UserRole role) {
  final siteItems = [
    for (final i in _siteNavItems)
      if (canAccessRoute(i.path, role)) i,
  ];

  List<_NavSlot> baseSlots;
  if (!_moreGroupedRoles.contains(role)) {
    baseSlots = [for (final t in tabs) _SingleSlot(t)];
  } else {
    final grouped = tabs.where((t) => _groupedPaths.contains(t.path)).toList();
    if (grouped.length < 2) {
      baseSlots = [for (final t in tabs) _SingleSlot(t)];
    } else {
      final slots = <_NavSlot>[];
      var inserted = false;
      for (final t in tabs) {
        if (_groupedPaths.contains(t.path)) {
          if (!inserted) {
            slots.add(
              _PopupSlot(
                key: 'more',
                label: 'More',
                icon: Icons.grid_view_outlined,
                selectedIcon: Icons.grid_view_rounded,
                items: grouped,
              ),
            );
            inserted = true;
          }
          continue;
        }
        slots.add(_SingleSlot(t));
      }
      baseSlots = slots;
    }
  }

  if (siteItems.isNotEmpty) {
    baseSlots.add(
      _PopupSlot(
        key: 'site',
        label: 'Site',
        icon: Icons.language_outlined,
        selectedIcon: Icons.language,
        items: siteItems,
      ),
    );
  }

  return baseSlots;
}

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
    final slots = _buildSlots(tabs, role);

    final onAccount = _onAccountPage(location);

    // Only watch a queue if the role can even see that tab — no point
    // polling it for roles who never see the entry at all.
    final canSeeApprovals = tabs.any((t) => t.path == '/approvals');
    final hasPendingApprovals = canSeeApprovals
        ? ref
              .watch(approvalsQueueProvider)
              .maybeWhen(data: (q) => !q.isEmpty, orElse: () => false)
        : false;

    final canSeeReviews = canAccessRoute('/reviews', role);
    final hasPendingReviews = canSeeReviews
        ? ref
              .watch(pendingReviewsProvider)
              .maybeWhen(data: (r) => r.isNotEmpty, orElse: () => false)
        : false;

    final canSeePublishQueue = role == UserRole.admin;
    final hasPendingPublishQueue = canSeePublishQueue
        ? ref
              .watch(publishQueueProvider)
              .maybeWhen(data: (s) => s.pendingCount > 0, orElse: () => false)
        : false;

    // Keyed by popup slot key ('more' / 'site') plus any direct-tab paths —
    // _FloatingNavBar checks both depending on the slot type.
    final pendingDots = <String, bool>{
      '/approvals': hasPendingApprovals,
      'site': hasPendingReviews || hasPendingPublishQueue,
    };

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
                slots: slots,
                location: location,
                onAccount: onAccount,
                scheme: scheme,
                pendingDots: pendingDots,
                onNavigate: (path) => context.go(path),
                onAccountTap: () => context.go('/me'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingNavBar extends StatefulWidget {
  final List<_NavSlot> slots;
  final String location;
  final bool onAccount;
  final ColorScheme scheme;
  final Map<String, bool> pendingDots;
  final ValueChanged<String> onNavigate;
  final VoidCallback onAccountTap;

  const _FloatingNavBar({
    required this.slots,
    required this.location,
    required this.onAccount,
    required this.scheme,
    required this.pendingDots,
    required this.onNavigate,
    required this.onAccountTap,
  });

  @override
  State<_FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<_FloatingNavBar> {
  String? _openPopupKey;

  Color _colorFor(String path) {
    switch (path) {
      case '/business':
        return AppColors.turmeric;
      case '/stock':
        return AppColors.cumin;
      case '/approvals':
        return const Color(0xFF3D6B57);
      case '/catalog':
        return AppColors.paprika;
      case '/reviews':
        return const Color(0xFF3D6B57);
      case '/publish-queue':
        return const Color(0xFF2E7D32);
      case '/analytics':
        return AppColors.turmeric;
      default:
        return AppColors.maroon;
    }
  }

  void _openPopup(_PopupSlot slot) {
    setState(() => _openPopupKey = slot.key);
    NavMoreSheet.show(
      context,
      bottomOffset:
          LayoutConstants.navBarBottomMargin +
          LayoutConstants.navBarHeight +
          14,
      items: [
        for (final item in slot.items)
          NavMoreItem(
            icon: item.icon,
            label: item.label,
            color: _colorFor(item.path),
            onTap: () => widget.onNavigate(item.path),
          ),
      ],
      onDismissed: () {
        if (mounted) setState(() => _openPopupKey = null);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final location = widget.location;
    final onAccount = widget.onAccount;

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
                    for (final slot in widget.slots)
                      if (slot is _SingleSlot)
                        _NavIcon(
                          icon: slot.item.icon,
                          selectedIcon: slot.item.selectedIcon,
                          label: slot.item.label,
                          selected:
                              !onAccount && location.startsWith(slot.item.path),
                          showDot: widget.pendingDots[slot.item.path] ?? false,
                          onTap: () => widget.onNavigate(slot.item.path),
                        )
                      else if (slot is _PopupSlot)
                        _NavIcon(
                          icon: slot.icon,
                          selectedIcon: slot.selectedIcon,
                          label: slot.label,
                          selected:
                              !onAccount &&
                              (_openPopupKey == slot.key ||
                                  slot.items.any(
                                    (i) => location.startsWith(i.path),
                                  )),
                          showDot:
                              widget.pendingDots[slot.key] ??
                              slot.items.any(
                                (i) => widget.pendingDots[i.path] == true,
                              ),
                          onTap: () => _openPopup(slot),
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
                onTap: widget.onAccountTap,
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
