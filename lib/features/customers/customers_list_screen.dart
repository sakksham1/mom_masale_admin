// lib/features/customers/customers_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'customers_api.dart';
import 'customers_provider.dart';
import '../../core/auth/user_role.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/currency.dart';
import '../../core/constants/layout_constants.dart';
import '../../shared/widgets/status_badge.dart';

const _assignableRoles = [
  UserRole.customer,
  UserRole.salesperson,
  UserRole.packaging,
  UserRole.warehouser,
  UserRole.manager,
  UserRole.admin,
];

String _roleLabel(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'Admin';
    case UserRole.manager:
      return 'Manager';
    case UserRole.warehouser:
      return 'Warehouser';
    case UserRole.packaging:
      return 'Packaging';
    case UserRole.salesperson:
      return 'Salesperson';
    case UserRole.customer:
      return 'Customer';
    case UserRole.unknown:
      return 'Unknown';
  }
}

class CustomersTab extends ConsumerWidget {
  /// Whether the role-change menu is shown. The backend (roles.js) is
  /// admin-only regardless, so this is a UI convenience, not the real gate.
  final bool editable;

  /// If set, only users whose role is in this set are shown. Lets one
  /// provider/endpoint (which returns every user) power both a
  /// "Customers" view and a "Staff" view.
  final Set<UserRole>? roleFilter;

  final String emptyMessage;

  const CustomersTab({
    super.key,
    this.editable = true,
    this.roleFilter,
    this.emptyMessage = 'No registered customers yet.',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(customersProvider),
      child: customersAsync.when(
        data: (customers) {
          final filtered = roleFilter == null
              ? customers
              : customers.where((c) => roleFilter!.contains(c.role)).toList();

          if (filtered.isEmpty) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text(emptyMessage)),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(
              bottom: LayoutConstants.navBarClearance,
            ),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) =>
                _CustomerTile(customer: filtered[i], editable: editable),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
      ),
    );
  }
}

class _CustomerTile extends ConsumerStatefulWidget {
  final Customer customer;
  final bool editable;
  const _CustomerTile({required this.customer, required this.editable});

  @override
  ConsumerState<_CustomerTile> createState() => _CustomerTileState();
}

class _CustomerTileState extends ConsumerState<_CustomerTile> {
  bool _busy = false;

  Future<void> _changeRole(UserRole newRole) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change role?'),
        content: Text(
          'Set ${widget.customer.name} to "${_roleLabel(newRole)}"? '
          'This takes effect on their next request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(customersApiProvider)
          .updateRole(widget.customer.id, newRole.name);
      ref.invalidate(customersProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    return ListTile(
      leading: RoleAvatar(role: c.role),
      title: Row(
        children: [
          Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          Chip(
            label: Text(
              _roleLabel(c.role),
              style: const TextStyle(fontSize: 11),
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
      subtitle: Text(c.phone != null ? '${c.email} · ${c.phone}' : c.email),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatRupees(c.lifetimeSpend),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${c.orderCount} order${c.orderCount == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                if (widget.editable)
                  PopupMenuButton<UserRole>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: _changeRole,
                    itemBuilder: (context) => _assignableRoles
                        .where((r) => r != c.role)
                        .map(
                          (r) => PopupMenuItem(
                            value: r,
                            child: Text('Set as ${_roleLabel(r)}'),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
    );
  }
}
