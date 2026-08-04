// lib/features/customers/customers_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'customers_api.dart';
import 'customers_provider.dart';
import 'customer_detail_screen.dart';
import 'role_display.dart';
import '../../core/auth/user_role.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/tap_scale.dart';
import '../../shared/widgets/staggered_fade_in.dart';

enum _SortMode { newest, oldest, nameAz, mostOrders, highestSpend }

/// Simplified, tappable account list. Each row shows only role + name +
/// email — everything else (contact, account, activity, role assignment)
/// lives on CustomerDetailScreen, reached by tapping a row.
class CustomersTab extends ConsumerStatefulWidget {
  /// Whether role assignment is available on the detail screen. The
  /// backend (roles.js) is admin-only regardless — this is a UI gate.
  final bool editable;

  /// If set, only accounts whose role is in this set are shown.
  final Set<UserRole>? roleFilter;

  final String emptyMessage;

  const CustomersTab({
    super.key,
    this.editable = true,
    this.roleFilter,
    this.emptyMessage = 'No registered customers yet.',
  });

  @override
  ConsumerState<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends ConsumerState<CustomersTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _SortMode _sort = _SortMode.newest;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Customer> _process(List<Customer> customers) {
    var list = widget.roleFilter == null
        ? customers
        : customers.where((c) => widget.roleFilter!.contains(c.role)).toList();

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) ||
                c.email.toLowerCase().contains(q) ||
                (c.phone ?? '').contains(q),
          )
          .toList();
    }

    list = List.of(list);
    switch (_sort) {
      case _SortMode.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case _SortMode.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case _SortMode.nameAz:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case _SortMode.mostOrders:
        list.sort((a, b) => b.orderCount.compareTo(a.orderCount));
        break;
      case _SortMode.highestSpend:
        list.sort((a, b) => b.lifetimeSpend.compareTo(a.lifetimeSpend));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search name, email, or phone…',
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
          child: SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _SortChip(
                  label: 'Newest',
                  selected: _sort == _SortMode.newest,
                  onTap: () => setState(() => _sort = _SortMode.newest),
                ),
                const SizedBox(width: 8),
                _SortChip(
                  label: 'Oldest',
                  selected: _sort == _SortMode.oldest,
                  onTap: () => setState(() => _sort = _SortMode.oldest),
                ),
                const SizedBox(width: 8),
                _SortChip(
                  label: 'Name A–Z',
                  selected: _sort == _SortMode.nameAz,
                  onTap: () => setState(() => _sort = _SortMode.nameAz),
                ),
                const SizedBox(width: 8),
                _SortChip(
                  label: 'Most Orders',
                  selected: _sort == _SortMode.mostOrders,
                  onTap: () => setState(() => _sort = _SortMode.mostOrders),
                ),
                const SizedBox(width: 8),
                _SortChip(
                  label: 'Highest Spend',
                  selected: _sort == _SortMode.highestSpend,
                  onTap: () => setState(() => _sort = _SortMode.highestSpend),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(customersProvider),
            child: customersAsync.when(
              data: (customers) {
                final list = _process(customers);
                if (list.isEmpty) {
                  return ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 64),
                        child: Center(
                          child: Text(
                            customers.isEmpty
                                ? widget.emptyMessage
                                : 'No accounts match "$_query".',
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    8,
                    12,
                    LayoutConstants.navBarClearance,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => StaggeredFadeIn(
                    key: ValueKey('cust_fade_${list[i].id}'),
                    index: i,
                    child: _CustomerTile(
                      key: ValueKey('cust_${list[i].id}'),
                      customer: list[i],
                      canEdit: widget.editable,
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load: $e')),
            ),
          ),
        ),
      ],
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortChip({
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

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final bool canEdit;
  const _CustomerTile({
    super.key,
    required this.customer,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = roleColor(customer.role);

    return TapScale(
      scaleDown: 0.985,
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) =>
              CustomerDetailScreen(customer: customer, canEdit: canEdit),
        ),
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
          children: [
            RoleAvatar(role: customer.role),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    customer.email,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                roleLabel(customer.role),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
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
