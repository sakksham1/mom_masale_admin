// lib/features/customers/customer_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'customers_api.dart';
import 'customers_provider.dart';
import 'role_display.dart';
import '../../core/auth/user_role.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/success_pulse.dart';
import '../../shared/widgets/swipe_to_confirm.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/tap_scale.dart';
import '../orders/orders_api.dart';
import '../orders/orders_provider.dart';
import '../orders/order_detail_screen.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final Customer customer;
  final bool canEdit;
  const CustomerDetailScreen({
    super.key,
    required this.customer,
    required this.canEdit,
  });

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  late Customer _customer;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '—';
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  Future<void> _openRolePicker() async {
    final chosen = await showModalBottomSheet<UserRole>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RolePickerSheet(current: _customer.role),
    );
    if (chosen == null || chosen == _customer.role || !mounted) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmAssignSheet(customer: _customer, newRole: chosen),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(customersApiProvider)
          .updateRole(_customer.id, chosen.name);
      Haptics.success();
      ref.invalidate(customersProvider);
      setState(() {
        _customer = Customer(
          id: _customer.id,
          name: _customer.name,
          email: _customer.email,
          phone: _customer.phone,
          role: chosen,
          createdAt: _customer.createdAt,
          orderCount: _customer.orderCount,
          lifetimeSpend: _customer.lifetimeSpend,
          signupPlatform: _customer.signupPlatform,
        );
      });
      if (mounted) {
        await SuccessPulse.show(
          context,
          'Role updated to ${roleLabel(chosen)}',
        );
      }
    } on ApiException catch (e) {
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _openOrder(Order order) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) =>
            OrderDetailScreen(order: order, editable: widget.canEdit),
      ),
    );
  }

  void _openAllOrders(List<Order> orders) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => _CustomerOrdersListScreen(
          customerName: _customer.name,
          orders: orders,
          editable: widget.canEdit,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = _customer;
    final color = roleColor(c.role);
    final ordersAsync = ref.watch(ordersProvider(null));

    return Scaffold(
      appBar: AppBar(title: Text(c.name, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.16),
                  color.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.4),
                      width: 1.4,
                    ),
                  ),
                  child: Icon(roleIcon(c.role), color: color, size: 32),
                ),
                const SizedBox(height: 14),
                Text(
                  c.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    roleLabel(c.role),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _SectionCard(
            icon: Icons.badge_outlined,
            title: 'Contact',
            children: [
              _DetailRow(
                icon: Icons.mail_outline,
                label: 'Email',
                value: c.email,
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.call_outlined,
                label: 'Phone',
                value: c.phone ?? 'Not provided',
              ),
            ],
          ),

          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.info_outline,
            title: 'Account',
            children: [
              _DetailRow(
                icon: Icons.tag,
                label: 'Account ID',
                value: '#${c.id}',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.event_outlined,
                label: 'Member since',
                value: _formatDate(c.createdAt),
              ),
              if (c.signupPlatform != null) ...[
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.devices_other,
                  label: 'Signed up via',
                  value: c.signupPlatform!,
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.receipt_long_outlined,
                  label: 'Orders',
                  value: '${c.orderCount}',
                  color: AppColors.turmeric,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Lifetime Spend',
                  value: formatRupees(c.lifetimeSpend),
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.receipt_long_outlined,
            title: 'Orders',
            children: [
              ordersAsync.when(
                data: (orders) {
                  final mine = orders.where((o) => o.userId == c.id).toList();
                  if (mine.isEmpty) {
                    return Text(
                      'No orders placed yet.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    );
                  }
                  final preview = mine.take(5).toList();
                  return Column(
                    children: [
                      for (final o in preview)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _OrderLinkRow(
                            order: o,
                            onTap: () => _openOrder(o),
                          ),
                        ),
                      if (mine.length > 5)
                        TextButton(
                          onPressed: () => _openAllOrders(mine),
                          child: Text('View all ${mine.length} orders'),
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (e, _) => Text('Could not load orders: $e'),
              ),
            ],
          ),

          if (widget.canEdit) ...[
            const SizedBox(height: 24),
            Text(
              'Role Management',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Changing a role updates what this account can access, effective '
              'on their next request.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openRolePicker,
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Assign a Different Role'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderLinkRow extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  const _OrderLinkRow({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TapScale(
      scaleDown: 0.985,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            OrderStatusBadge(
              status: order.status,
              paymentStatus: order.paymentStatus,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${order.id}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    order.createdAt.length >= 10
                        ? order.createdAt.substring(0, 10)
                        : order.createdAt,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatRupees(order.total),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Overflow screen for accounts with more than a handful of orders — reached
/// via "View all N orders" on the detail page.
class _CustomerOrdersListScreen extends StatelessWidget {
  final String customerName;
  final List<Order> orders;
  final bool editable;
  const _CustomerOrdersListScreen({
    required this.customerName,
    required this.orders,
    required this.editable,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$customerName — Orders')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _OrderLinkRow(
          order: orders[i],
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) =>
                  OrderDetailScreen(order: orders[i], editable: editable),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _RolePickerSheet extends StatelessWidget {
  final UserRole current;
  const _RolePickerSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                'Assign a role',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Choose the new role for this account.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              ...assignableRoles.map((r) {
                final isCurrent = r == current;
                final color = roleColor(r);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isCurrent
                        ? scheme.surfaceContainerLow
                        : color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: isCurrent ? null : () => Navigator.pop(context, r),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              roleIcon(r),
                              color: isCurrent
                                  ? scheme.onSurfaceVariant
                                  : color,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                roleLabel(r),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isCurrent
                                      ? scheme.onSurfaceVariant
                                      : null,
                                ),
                              ),
                            ),
                            if (isCurrent)
                              Text(
                                'Current',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              )
                            else
                              Icon(Icons.chevron_right, color: color, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmAssignSheet extends StatelessWidget {
  final Customer customer;
  final UserRole newRole;
  const _ConfirmAssignSheet({required this.customer, required this.newRole});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = roleColor(newRole);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium,
                          children: [
                            const TextSpan(text: 'Set '),
                            TextSpan(
                              text: customer.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(text: ' to '),
                            TextSpan(
                              text: roleLabel(newRole),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  '? This takes effect on their next request.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SwipeToConfirm(
                label: 'Slide to confirm',
                color: color,
                onConfirmed: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
