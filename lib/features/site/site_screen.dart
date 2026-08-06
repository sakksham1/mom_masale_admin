// lib/features/site/site_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/route_permissions.dart';
import '../../core/auth/user_role.dart';
import '../../core/network/api_client_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/layout_constants.dart';
import '../../shared/widgets/tap_scale.dart';
import '../../shared/widgets/staggered_fade_in.dart';
import '../reviews/reviews_provider.dart';
import '../publish_queue/publish_queue_provider.dart';

/// The former "Site" popup, now its own screen — a clean list of cards
/// linking to every site-content area. Moved out of NavMoreSheet because
/// the popup was getting too cluttered once Recipes/Blog/Site Settings
/// joined Catalog/Reviews/Publish Queue/Analytics.
class _SiteCardMeta {
  final String path;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _SiteCardMeta({
    required this.path,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}

// Order matches the requested layout: Catalog, Reviews, Publish Queue,
// Analytics, Recipes, Blog, Site Settings.
const _cards = <_SiteCardMeta>[
  _SiteCardMeta(
    path: '/catalog',
    icon: Icons.category_outlined,
    title: 'Catalog',
    subtitle: 'Products, pricing & visibility',
    color: AppColors.paprika,
  ),
  _SiteCardMeta(
    path: '/reviews',
    icon: Icons.rate_review_outlined,
    title: 'Reviews',
    subtitle: 'Moderate customer reviews',
    color: Color(0xFF3D6B57),
  ),
  _SiteCardMeta(
    path: '/publish-queue',
    icon: Icons.publish_outlined,
    title: 'Publish Queue',
    subtitle: 'Review & push pending changes live',
    color: Color(0xFF2E7D32),
  ),
  _SiteCardMeta(
    path: '/analytics',
    icon: Icons.query_stats_outlined,
    title: 'Analytics',
    subtitle: 'Traffic, funnels & search terms',
    color: AppColors.turmeric,
  ),
  _SiteCardMeta(
    path: '/recipes',
    icon: Icons.restaurant_menu_outlined,
    title: 'Recipes',
    subtitle: 'Publish and edit recipes',
    color: Color(0xFFB0752B),
  ),
  _SiteCardMeta(
    path: '/blog',
    icon: Icons.article_outlined,
    title: 'Blog',
    subtitle: 'Articles, FAQs & guides',
    color: Color(0xFF3D6B57),
  ),
  _SiteCardMeta(
    path: '/site-core',
    icon: Icons.tune_outlined,
    title: 'Site Settings',
    subtitle: 'Shipping, pricing & business info',
    color: AppColors.maroon,
  ),
];

class SiteScreen extends ConsumerWidget {
  const SiteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authControllerProvider).role;
    final visible = _cards.where((c) => canAccessRoute(c.path, role)).toList();

    final hasPendingReviews = canAccessRoute('/reviews', role)
        ? ref
              .watch(pendingReviewsProvider)
              .maybeWhen(data: (r) => r.isNotEmpty, orElse: () => false)
        : false;
    final hasPendingPublish = role == UserRole.admin
        ? ref
              .watch(publishQueueProvider)
              .maybeWhen(data: (s) => s.pendingCount > 0, orElse: () => false)
        : false;

    bool dotFor(String path) {
      if (path == '/reviews') return hasPendingReviews;
      if (path == '/publish-queue') return hasPendingPublish;
      return false;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Site')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          LayoutConstants.navBarClearance,
        ),
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => StaggeredFadeIn(
          key: ValueKey('site_card_${visible[i].path}'),
          index: i,
          child: _SiteCard(meta: visible[i], showDot: dotFor(visible[i].path)),
        ),
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  final _SiteCardMeta meta;
  final bool showDot;
  const _SiteCard({required this.meta, required this.showDot});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TapScale(
      scaleDown: 0.98,
      onTap: () => context.push(meta.path),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              meta.color.withValues(alpha: 0.14),
              meta.color.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: meta.color.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(meta.icon, color: meta.color, size: 24),
                ),
                if (showDot)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC62828),
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meta.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta.subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
