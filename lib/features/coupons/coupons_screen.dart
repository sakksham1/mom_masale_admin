import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'coupons_api.dart';
import 'coupons_provider.dart';
import 'coupon_edit_screen.dart';
import '../../core/auth/user_role.dart';
import '../../core/network/api_client_provider.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/currency.dart';
import '../../shared/widgets/tap_scale.dart';
import '../../shared/widgets/staggered_fade_in.dart';

enum _CouponFilter { all, active, inactive }

class CouponsScreen extends ConsumerStatefulWidget {
  const CouponsScreen({super.key});

  @override
  ConsumerState<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends ConsumerState<CouponsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _CouponFilter _filter = _CouponFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openNew() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const CouponEditScreen(coupon: null)),
    );
    ref.invalidate(couponsProvider);
  }

  Future<void> _openEdit(Coupon coupon) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => CouponEditScreen(coupon: coupon)),
    );
    ref.invalidate(couponsProvider);
  }

  List<Coupon> _process(List<Coupon> coupons) {
    var list = coupons;
    switch (_filter) {
      case _CouponFilter.active:
        list = list.where((c) => c.isActive).toList();
        break;
      case _CouponFilter.inactive:
        list = list.where((c) => !c.isActive).toList();
        break;
      case _CouponFilter.all:
        break;
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where(
            (c) =>
                c.code.toLowerCase().contains(q) ||
                (c.description ?? '').toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final couponsAsync = ref.watch(couponsProvider);
    final role = ref.watch(authControllerProvider).role;
    final isAdmin = role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(title: const Text('Coupons')),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
          bottom: LayoutConstants.fabScaffoldExtraPadding,
        ),
        child: FloatingActionButton.extended(
          onPressed: _openNew,
          icon: const Icon(Icons.add),
          label: const Text('New Coupon'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search code or description…',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == _CouponFilter.all,
                  onTap: () => setState(() => _filter = _CouponFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Active',
                  selected: _filter == _CouponFilter.active,
                  onTap: () => setState(() => _filter = _CouponFilter.active),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Inactive',
                  selected: _filter == _CouponFilter.inactive,
                  onTap: () =>
                      setState(() => _filter = _CouponFilter.inactive),
                ),
                const Spacer(),
                if (!isAdmin)
                  Tooltip(
                    message: 'Changes you make are sent to an admin for approval.',
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(couponsProvider),
              child: couponsAsync.when(
                data: (coupons) {
                  final list = _process(coupons);
                  if (list.isEmpty) {
                    return ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 64),
                          child: Center(
                            child: Text(
                              coupons.isEmpty
                                  ? 'No coupons yet.'
                                  : 'No coupons match your filters.',
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      8,
                      12,
                      LayoutConstants.navBarClearance +
                          LayoutConstants.fabScaffoldExtraPadding,
                    ),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => StaggeredFadeIn(
                      key: ValueKey('coupon_fade_${list[i].id}'),
                      index: i,
                      child: _CouponTile(
                        key: ValueKey('coupon_${list[i].id}'),
                        coupon: list[i],
                        onTap: () => _openEdit(list[i]),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Could not load coupons: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.maroon,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? AppColors.parchment : null,
      ),
    );
  }
}

class _CouponTile extends StatelessWidget {
  final Coupon coupon;
  final VoidCallback onTap;
  const _CouponTile({super.key, required this.coupon, required this.onTap});

  String _valueLabel() {
    return coupon.type == 'percent'
        ? '${coupon.value.round()}% off'
        : '${formatRupees(coupon.value.round())} off';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = coupon.isActive && !coupon.isExhausted;
    final accent = !coupon.isActive
        ? const Color(0xFF8A97A3)
        : (coupon.isExhausted ? AppColors.paprika : const Color(0xFF2E7D32));

    return TapScale(
      scaleDown: 0.985,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                coupon.type == 'percent'
                    ? Icons.percent
                    : Icons.currency_rupee,
                color: accent,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          coupon.code,
                          style: AppTypography.ledger(
                            fontSize: 15,
                            color: scheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _valueLabel(),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                  if (coupon.description != null &&
                      coupon.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      coupon.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _MiniTag(
                        label: !coupon.isActive
                            ? 'Inactive'
                            : (coupon.isExhausted ? 'Exhausted' : 'Active'),
                        color: accent,
                      ),
                      if (coupon.usageLimit != null)
                        _MiniTag(
                          label: '${coupon.usedCount}/${coupon.usageLimit} used',
                          color: scheme.onSurfaceVariant,
                        )
                      else
                        _MiniTag(
                          label: '${coupon.usedCount} used',
                          color: scheme.onSurfaceVariant,
                        ),
                      if (coupon.minSubtotal > 0)
                        _MiniTag(
                          label: 'Min ${formatRupees(coupon.minSubtotal)}',
                          color: scheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
