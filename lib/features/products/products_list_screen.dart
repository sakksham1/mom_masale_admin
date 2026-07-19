import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'products_api.dart';
import 'products_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/currency.dart';

class ProductsListScreen extends ConsumerWidget {
  const ProductsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(productsProvider),
        child: productsAsync.when(
          data: (products) {
            if (products.isEmpty) {
              return const Center(child: Text('No products yet.'));
            }
            return ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, i) => _ProductTile(product: products[i]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load products: $e')),
        ),
      ),
    );
  }
}

class _ProductTile extends ConsumerWidget {
  final Product product;
  const _ProductTile({required this.product});

  Color? _stockColor(BuildContext context, int qty) {
    if (qty == 0) return Theme.of(context).colorScheme.error;
    if (qty <= 10) return Colors.orange.shade700;
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      leading: product.image.isNotEmpty
          ? CircleAvatar(backgroundImage: NetworkImage(product.image))
          : const CircleAvatar(child: Icon(Icons.image_not_supported_outlined)),
      title: Text(product.name),
      subtitle: Row(
        children: [
          Text(product.category),
          if (product.comingSoon) ...[
            const SizedBox(width: 6),
            const Chip(
              label: Text('Coming Soon', style: TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
          if (product.anyOutOfStock) ...[
            const SizedBox(width: 6),
            Chip(
              label: const Text('Out of stock', style: TextStyle(fontSize: 11)),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ] else if (product.anyLowStock) ...[
            const SizedBox(width: 6),
            Chip(
              label: const Text('Low stock', style: TextStyle(fontSize: 11)),
              backgroundColor: Colors.orange.shade100,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ],
      ),
      children: product.sizes
          .map(
            (size) => _SizeRow(
              product: product,
              size: size,
              stockColor: _stockColor(context, size.stockQty),
            ),
          )
          .toList(),
    );
  }
}

class _SizeRow extends ConsumerStatefulWidget {
  final Product product;
  final ProductSize size;
  final Color? stockColor;
  const _SizeRow({
    required this.product,
    required this.size,
    required this.stockColor,
  });

  @override
  ConsumerState<_SizeRow> createState() => _SizeRowState();
}

class _SizeRowState extends ConsumerState<_SizeRow> {
  bool _busy = false;

  Future<void> _adjust(
    int changeQty, {
    required String reason,
    String? note,
  }) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(productsApiProvider)
          .adjustStock(
            productId: widget.product.id,
            size: widget.size.size,
            changeQty: changeQty,
            reason: reason,
            note: note,
          );
      ref.invalidate(productsProvider);
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

  Future<void> _openSetStockDialog() async {
    final controller = TextEditingController(
      text: widget.size.stockQty.toString(),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set stock — ${widget.product.name} (${widget.size.size})'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New stock quantity'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value >= 0) Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result != widget.size.stockQty) {
      final delta = result - widget.size.stockQty;
      await _adjust(
        delta,
        reason: 'correction',
        note: 'manually set to $result via admin app',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 32, right: 16),
      title: Text(widget.size.size),
      subtitle: Text(formatRupees(widget.size.price)),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Decrease by 1',
                  onPressed: widget.size.stockQty > 0
                      ? () => _adjust(
                          -1,
                          reason: 'adjustment',
                          note: 'quick decrement via admin app',
                        )
                      : null,
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${widget.size.stockQty}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: widget.stockColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Increase by 1',
                  onPressed: () => _adjust(
                    1,
                    reason: 'restock',
                    note: 'quick increment via admin app',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Set exact quantity',
                  onPressed: _openSetStockDialog,
                ),
              ],
            ),
    );
  }
}
