import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'orders_api.dart';
import 'orders_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/currency.dart';
import '../../shared/widgets/status_badge.dart';

const _statusFlow = ['placed', 'packed', 'shipped', 'delivered', 'cancelled'];
const _paymentStatuses = ['created', 'paid', 'failed', 'cod'];

String _statusLabel(String s) => s[0].toUpperCase() + s.substring(1);

/// Next non-cancelled status after [current], or null if there isn't one
/// (already delivered/cancelled).
String? _nextStatus(String current) {
  final idx = _statusFlow.indexOf(current);
  if (idx == -1 || idx >= _statusFlow.length - 2)
    return null; // last real step is 'delivered'
  return _statusFlow[idx + 1];
}

class OrderDetailScreen extends ConsumerStatefulWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

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
          customerName: _order.customerName,
          phone: _order.phone,
          status: status,
          paymentStatus: paymentStatus,
          createdAt: _order.createdAt,
          total: _order.total,
          items: _order.items,
        );
        _status = status;
        _paymentStatus = paymentStatus;
      });
      // Refresh whichever filtered lists are cached so OrdersTab shows the change.
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          'Order #${_order.id} for ${_order.customerName} will be marked cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _persist(status: 'cancelled', paymentStatus: _order.paymentStatus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextStatus(_order.status);
    final canCancel =
        _order.status != 'cancelled' && _order.status != 'delivered';

    return Scaffold(
      appBar: AppBar(title: Text('Order #${_order.id}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _CustomerCard(order: _order),
          const SizedBox(height: 16),
          _ItemsCard(order: _order),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OrderStatusBadge(
                        status: _order.status,
                        paymentStatus: _order.paymentStatus,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'Fulfilment status',
                          ),
                          items: _statusFlow
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(_statusLabel(s)),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _status = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentStatus,
                    decoration: const InputDecoration(
                      labelText: 'Payment status',
                    ),
                    items: _paymentStatuses
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(_statusLabel(s)),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _paymentStatus = v!),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: (_saving || !_dirty)
                        ? null
                        : () => _persist(
                            status: _status,
                            paymentStatus: _paymentStatus,
                          ),
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Changes'),
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
                              onPressed: _saving ? null : _advance,
                              icon: const Icon(Icons.arrow_forward),
                              label: Text('Mark ${_statusLabel(next)}'),
                            ),
                          ),
                        if (next != null && canCancel)
                          const SizedBox(width: 12),
                        if (canCancel)
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              onPressed: _saving ? null : _cancel,
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Cancel'),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Order order;
  const _CustomerCard({required this.order});

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
                Icon(
                  Icons.person_outline,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.customerName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  formatRupees(order.total),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.call_outlined,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(order.phone),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(order.createdAt),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  final Order order;
  const _ItemsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Items',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ...order.items.map(
              (i) => ListTile(
                dense: true,
                title: Text('${i.productName} (${i.size})'),
                subtitle: Text('${i.qty} × ${formatRupees(i.unitPrice)}'),
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
