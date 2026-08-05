import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'orders_api.dart';
import 'orders_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/auth/user_role.dart';
import '../../core/network/api_client_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/tap_scale.dart';
import '../customers/customers_api.dart';
import '../customers/customers_provider.dart';
import '../customers/customer_detail_screen.dart';
import '../customers/role_display.dart';
import '../../shared/widgets/confirm_dialog.dart';

const _statusFlow = ['placed', 'packed', 'shipped', 'delivered', 'cancelled'];
const _paymentStatuses = ['created', 'paid', 'failed', 'cod'];

String _statusLabel(String s) => s[0].toUpperCase() + s.substring(1);

String? _nextStatus(String current) {
  final idx = _statusFlow.indexOf(current);
  if (idx == -1 || idx >= _statusFlow.length - 2) return null;
  return _statusFlow[idx + 1];
}

String _formatDateTime(String raw) {
  if (raw.isEmpty) return '—';
  var iso = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
  if (!iso.endsWith('Z') && !iso.contains('+')) iso += 'Z';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return raw;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour24 = dt.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final ampm = hour24 < 12 ? 'AM' : 'PM';
  final minute = dt.minute.toString().padLeft(2, '0');
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour12:$minute $ampm';
}

class OrderDetailScreen extends ConsumerStatefulWidget {
  final Order order;
  final bool editable;
  const OrderDetailScreen({
    super.key,
    required this.order,
    this.editable = true,
  });

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  late Order _order;
  late String _status;
  late String _paymentStatus;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _status = _order.status;
    _paymentStatus = _order.paymentStatus;
  }

  bool get _dirty =>
      _status != _order.status || _paymentStatus != _order.paymentStatus;

  Future<void> _persist({
    required String status,
    required String paymentStatus,
  }) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(ordersApiProvider)
          .updateOrder(_order.id, status: status, paymentStatus: paymentStatus);
      setState(() {
        _order = Order(
          id: _order.id,
          userId: _order.userId,
          customerName: _order.customerName,
          phone: _order.phone,
          email: _order.email,
          address: _order.address,
          city: _order.city,
          pincode: _order.pincode,
          status: status,
          paymentStatus: paymentStatus,
          createdAt: _order.createdAt,
          updatedAt: _order.updatedAt,
          subtotal: _order.subtotal,
          shippingFee: _order.shippingFee,
          total: _order.total,
          razorpayOrderId: _order.razorpayOrderId,
          razorpayPaymentId: _order.razorpayPaymentId,
          items: _order.items,
        );
        _status = status;
        _paymentStatus = paymentStatus;
      });
      ref.invalidate(ordersProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Order updated')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _advance() async {
    final next = _nextStatus(_order.status);
    if (next == null) return;
    await _persist(status: next, paymentStatus: _order.paymentStatus);
  }

  Future<void> _cancel() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Cancel this order?',
      message:
          'Order #${_order.id} for ${_order.customerName} will be marked cancelled.',
      icon: Icons.cancel_outlined,
      confirmLabel: 'Cancel Order',
      cancelLabel: 'Back',
      destructive: true,
    );
    if (confirmed) {
      await _persist(status: 'cancelled', paymentStatus: _order.paymentStatus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextStatus(_order.status);
    final canCancel =
        _order.status != 'cancelled' && _order.status != 'delivered';
    final role = ref.watch(authControllerProvider).role;
    final canEditCustomerRole = role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(title: Text('Order #${_order.id}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _HeroCard(order: _order),
          const SizedBox(height: 16),
          _CustomerLinkCard(order: _order, canEditRole: canEditCustomerRole),
          if (_order.address != null && _order.address!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _AddressCard(order: _order),
          ],
          const SizedBox(height: 16),
          _ItemsCard(order: _order),
          const SizedBox(height: 16),
          _PaymentCard(order: _order),
          const SizedBox(height: 16),
          _TimelineCard(order: _order),
          const SizedBox(height: 16),
          _StatusCard(
            order: _order,
            editable: widget.editable,
            status: _status,
            paymentStatus: _paymentStatus,
            saving: _saving,
            dirty: _dirty,
            next: next,
            canCancel: canCancel,
            onStatusChanged: (v) => setState(() => _status = v),
            onPaymentStatusChanged: (v) => setState(() => _paymentStatus = v),
            onSave: () =>
                _persist(status: _status, paymentStatus: _paymentStatus),
            onAdvance: _advance,
            onCancel: _cancel,
          ),
        ],
      ),
    );
  }
}

// ── Hero ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final Order order;
  const _HeroCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.maroon.withValues(alpha: 0.12),
            AppColors.maroon.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              OrderStatusBadge(
                status: order.status,
                paymentStatus: order.paymentStatus,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.id}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDateTime(order.createdAt),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatRupees(order.total),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.maroon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PillBadge(
                  label: _statusLabel(order.status),
                  icon: Icons.local_shipping_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PillBadge(
                  label: _statusLabel(order.paymentStatus),
                  icon: Icons.payments_outlined,
                ),
              ),
              if (order.isGuest) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _PillBadge(
                    label: 'Guest',
                    icon: Icons.person_off_outlined,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  const _PillBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared section shell ────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final List<Widget> children;
  const _SectionCard({
    required this.icon,
    required this.title,
    this.trailing,
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
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ?trailing,
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
  final bool mono;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
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
                Text(
                  value,
                  style: mono
                      ? const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 13)
                      : Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Customer link ────────────────────────────────────────────────────────

/// The interconnect: if the order has a linked account, look it up in the
/// same customers list the Business tab uses and render a tappable card
/// that opens that account's CustomerDetailScreen directly. If it's a
/// guest checkout (no user_id) or the account can't be resolved, falls
/// back to the raw contact details captured on the order itself.
class _CustomerLinkCard extends ConsumerWidget {
  final Order order;
  final bool canEditRole;
  const _CustomerLinkCard({required this.order, required this.canEditRole});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    Widget contactRows() => Column(
      children: [
        _DetailRow(
          icon: Icons.person_outline,
          label: 'Name',
          value: order.customerName,
        ),
        _DetailRow(
          icon: Icons.call_outlined,
          label: 'Phone',
          value: order.phone,
        ),
        if (order.email != null && order.email!.isNotEmpty)
          _DetailRow(
            icon: Icons.mail_outline,
            label: 'Email',
            value: order.email!,
          ),
      ],
    );

    if (order.isGuest) {
      return _SectionCard(
        icon: Icons.person_outline,
        title: 'Customer',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Guest checkout',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
          ),
        ),
        children: [contactRows()],
      );
    }

    final customersAsync = ref.watch(customersProvider);

    return _SectionCard(
      icon: Icons.person_outline,
      title: 'Customer',
      children: [
        customersAsync.when(
          data: (customers) {
            Customer? match;
            for (final c in customers) {
              if (c.id == order.userId) {
                match = c;
                break;
              }
            }
            if (match == null) {
              return contactRows();
            }
            final c = match;
            final color = roleColor(c.role);
            return Column(
              children: [
                TapScale(
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerDetailScreen(
                        customer: c,
                        canEdit: canEditRole,
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        RoleAvatar(role: c.role),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${roleLabel(c.role)} · ${c.orderCount} order${c.orderCount == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: color, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                contactRows(),
              ],
            );
          },
          loading: () => Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              contactRows(),
            ],
          ),
          error: (e, _) => contactRows(),
        ),
      ],
    );
  }
}

// ── Address ──────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final Order order;
  const _AddressCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final line = [
      order.city,
      order.pincode,
    ].where((s) => s != null && s.isNotEmpty).join(' · ');
    return _SectionCard(
      icon: Icons.location_on_outlined,
      title: 'Shipping Address',
      children: [
        Text(
          order.address ?? '—',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (line.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            line,
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Items ────────────────────────────────────────────────────────────────

class _ItemsCard extends StatelessWidget {
  final Order order;
  const _ItemsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Items (${order.items.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            ...order.items.map(
              (i) => ListTile(
                dense: true,
                title: Text('${i.productName} (${i.size})'),
                subtitle: Text(
                  i.productSlug.isNotEmpty
                      ? '${i.qty} × ${formatRupees(i.unitPrice)} · ${i.productSlug}'
                      : '${i.qty} × ${formatRupees(i.unitPrice)}',
                ),
                trailing: Text(
                  formatRupees(i.qty * i.unitPrice),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Payment ──────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  final Order order;
  const _PaymentCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SectionCard(
      icon: Icons.payments_outlined,
      title: 'Payment',
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Subtotal',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            Text(formatRupees(order.subtotal)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Shipping',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
            Text(
              order.shippingFee == 0 ? 'Free' : formatRupees(order.shippingFee),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1),
        ),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              formatRupees(order.total),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.maroon,
              ),
            ),
          ],
        ),
        if (order.razorpayOrderId != null ||
            order.razorpayPaymentId != null) ...[
          const SizedBox(height: 16),
          if (order.razorpayOrderId != null)
            _DetailRow(
              icon: Icons.receipt_outlined,
              label: 'Razorpay Order ID',
              value: order.razorpayOrderId!,
              mono: true,
            ),
          if (order.razorpayPaymentId != null)
            _DetailRow(
              icon: Icons.confirmation_number_outlined,
              label: 'Razorpay Payment ID',
              value: order.razorpayPaymentId!,
              mono: true,
            ),
        ],
      ],
    );
  }
}

// ── Timeline ─────────────────────────────────────────────────────────────

class _TimelineCard extends StatelessWidget {
  final Order order;
  const _TimelineCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.schedule_outlined,
      title: 'Timeline',
      children: [
        _DetailRow(
          icon: Icons.add_circle_outline,
          label: 'Placed',
          value: _formatDateTime(order.createdAt),
        ),
        _DetailRow(
          icon: Icons.update,
          label: 'Last updated',
          value: _formatDateTime(order.updatedAt),
        ),
      ],
    );
  }
}

// ── Status editor ────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final Order order;
  final bool editable, saving, dirty, canCancel;
  final String status, paymentStatus;
  final String? next;
  final ValueChanged<String> onStatusChanged, onPaymentStatusChanged;
  final VoidCallback onSave, onAdvance, onCancel;

  const _StatusCard({
    required this.order,
    required this.editable,
    required this.status,
    required this.paymentStatus,
    required this.saving,
    required this.dirty,
    required this.next,
    required this.canCancel,
    required this.onStatusChanged,
    required this.onPaymentStatusChanged,
    required this.onSave,
    required this.onAdvance,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (!editable) {
      return _SectionCard(
        icon: Icons.flag_outlined,
        title: 'Status',
        children: [
          Row(
            children: [
              OrderStatusBadge(
                status: order.status,
                paymentStatus: order.paymentStatus,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_statusLabel(order.status)} · ${_statusLabel(order.paymentStatus)}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return _SectionCard(
      icon: Icons.flag_outlined,
      title: 'Update Status',
      children: [
        DropdownButtonFormField<String>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Fulfilment status'),
          items: _statusFlow
              .map(
                (s) => DropdownMenuItem(value: s, child: Text(_statusLabel(s))),
              )
              .toList(),
          onChanged: saving ? null : (v) => onStatusChanged(v!),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: paymentStatus,
          decoration: const InputDecoration(labelText: 'Payment status'),
          items: _paymentStatuses
              .map(
                (s) => DropdownMenuItem(value: s, child: Text(_statusLabel(s))),
              )
              .toList(),
          onChanged: saving ? null : (v) => onPaymentStatusChanged(v!),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (saving || !dirty) ? null : onSave,
            child: saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Changes'),
          ),
        ),
        if (next != null || canCancel) ...[
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              if (next != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : onAdvance,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text('Mark ${_statusLabel(next!)}'),
                  ),
                ),
              if (next != null && canCancel) const SizedBox(width: 12),
              if (canCancel)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    onPressed: saving ? null : onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel'),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
