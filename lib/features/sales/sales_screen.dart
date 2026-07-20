import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sales_api.dart';
import 'sales_provider.dart';
import '../packaging/packaging_api.dart' show StaffProduct;
import '../packaging/packaging_provider.dart' show staffProductsProvider;
import '../../core/network/api_exception.dart';
import '../../core/utils/currency.dart';

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(salesStatsProvider);
    final reportsAsync = ref.watch(mySalesReportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSubmitFlow(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Report Sale'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(salesStatsProvider);
          ref.invalidate(mySalesReportsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text('My Totals', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            statsAsync.when(
              data: (stats) => Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'Reports',
                      value: '${stats.totals.reportCount}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      label: 'Qty Sold',
                      value: '${stats.totals.totalQty}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      label: 'Amount',
                      value: formatRupees(stats.totals.totalAmount.round()),
                    ),
                  ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Could not load stats: $e'),
            ),
            const SizedBox(height: 24),
            Text(
              'Recent Reports',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            reportsAsync.when(
              data: (reports) {
                if (reports.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No reports yet.'),
                  );
                }
                return Column(
                  children: reports
                      .map(
                        (r) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${r.productName} (${r.size}) × ${r.qty}',
                          ),
                          subtitle: Text(
                            r.customerName != null
                                ? '${r.reportDate} · ${r.customerName}'
                                : r.reportDate,
                          ),
                          trailing: Text(
                            formatRupees(r.saleAmount.round()),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Could not load reports: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSubmitFlow(BuildContext context, WidgetRef ref) async {
    final productsAsync = ref.read(staffProductsProvider);
    final products = productsAsync.value;
    if (products == null || products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Products are still loading — try again in a moment.'),
        ),
      );
      return;
    }

    final result = await showDialog<_SaleInput>(
      context: context,
      builder: (_) => _SubmitSaleDialog(products: products),
    );
    if (result == null) return;

    try {
      await ref
          .read(salesApiProvider)
          .submitReport(
            productId: result.productId,
            size: result.size,
            qty: result.qty,
            saleAmount: result.saleAmount,
            customerName: result.customerName,
          );
      ref.invalidate(salesStatsProvider);
      ref.invalidate(mySalesReportsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sale reported')));
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _StatTile extends StatelessWidget {
  final String label, value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SaleInput {
  final int productId;
  final String size;
  final int qty;
  final num saleAmount;
  final String? customerName;
  _SaleInput(
    this.productId,
    this.size,
    this.qty,
    this.saleAmount,
    this.customerName,
  );
}

class _SubmitSaleDialog extends StatefulWidget {
  final List<StaffProduct> products;
  const _SubmitSaleDialog({required this.products});

  @override
  State<_SubmitSaleDialog> createState() => _SubmitSaleDialogState();
}

class _SubmitSaleDialogState extends State<_SubmitSaleDialog> {
  StaffProduct? _product;
  String? _size;
  final _qtyCtrl = TextEditingController(text: '1');
  final _amountCtrl = TextEditingController();
  final _customerCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report a Sale'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<StaffProduct>(
              initialValue: _product,
              decoration: const InputDecoration(labelText: 'Product'),
              items: widget.products
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                  .toList(),
              onChanged: (p) => setState(() {
                _product = p;
                _size = null;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _size,
              decoration: const InputDecoration(labelText: 'Size'),
              items: (_product?.sizes ?? [])
                  .map(
                    (s) => DropdownMenuItem(value: s.size, child: Text(s.size)),
                  )
                  .toList(),
              onChanged: _product == null
                  ? null
                  : (s) => setState(() => _size = s),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Sale amount (₹)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customerCtrl,
              decoration: const InputDecoration(
                labelText: 'Customer name (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final product = _product;
            final size = _size;
            final qty = int.tryParse(_qtyCtrl.text.trim());
            final amount = num.tryParse(_amountCtrl.text.trim());
            if (product == null ||
                size == null ||
                qty == null ||
                qty <= 0 ||
                amount == null ||
                amount < 0) {
              return;
            }
            Navigator.pop(
              context,
              _SaleInput(
                product.id,
                size,
                qty,
                amount,
                _customerCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
