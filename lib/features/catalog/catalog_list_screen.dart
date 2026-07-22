import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'catalog_api.dart';
import 'catalog_provider.dart';
import 'product_edit_screen.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency.dart';
import '../../shared/widgets/product_avatar.dart';
import '../../shared/widgets/tap_scale.dart';
import '../../shared/widgets/staggered_fade_in.dart';

/// Read-only-until-you-tap catalog browser. Admins edit directly; managers
/// submit changes that wait for admin approval — the edit screen itself
/// decides which, based on role. Deliberately has no stock/quantity fields
/// anywhere — inventory stays in the Stock tab.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(catalogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Product Catalog')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search products…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(catalogProvider),
              child: productsAsync.when(
                data: (products) {
                  final filtered = _query.isEmpty
                      ? products
                      : products
                            .where(
                              (p) =>
                                  p.name.toLowerCase().contains(
                                    _query.toLowerCase(),
                                  ) ||
                                  p.category.toLowerCase().contains(
                                    _query.toLowerCase(),
                                  ),
                            )
                            .toList();

                  if (filtered.isEmpty) {
                    return ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 64),
                          child: Center(
                            child: Text(
                              products.isEmpty
                                  ? 'No products yet.'
                                  : 'No products match "$_query".',
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      12,
                      4,
                      12,
                      LayoutConstants.navBarClearance,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => StaggeredFadeIn(
                      key: ValueKey('cat_fade_${filtered[i].id}'),
                      index: i,
                      child: _CatalogTile(
                        key: ValueKey('cat_${filtered[i].id}'),
                        product: filtered[i],
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Could not load catalog: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  final CatalogProduct product;
  const _CatalogTile({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final prices = product.sizes.map((s) => s.price).toList();
    final priceLabel = prices.isEmpty
        ? '—'
        : prices.length == 1
        ? formatRupees(prices.first.round())
        : '${formatRupees(prices.reduce((a, b) => a < b ? a : b).round())}–'
              '${formatRupees(prices.reduce((a, b) => a > b ? a : b).round())}';

    return TapScale(
      scaleDown: 0.985,
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => ProductEditScreen(product: product)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ProductAvatar(image: product.image, radius: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (product.comingSoon ||
                      product.featured ||
                      product.bestseller ||
                      product.newArrival) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (product.comingSoon)
                          const _FlagChip('Coming Soon', AppColors.paprika),
                        if (product.featured)
                          const _FlagChip('Featured', AppColors.turmeric),
                        if (product.bestseller)
                          const _FlagChip('Bestseller', AppColors.maroon),
                        if (product.newArrival)
                          const _FlagChip('New', Color(0xFF2E7D32)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  priceLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FlagChip extends StatelessWidget {
  final String label;
  final Color color;
  const _FlagChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
