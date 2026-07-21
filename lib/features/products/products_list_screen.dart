// lib/features/products/products_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'products_api.dart';
import 'products_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/currency.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/product_avatar.dart';

/// Products tab of the Inventory screen. View-only for packaging, manager,
/// admin. Warehouser sees an edit button per size that opens a bottom sheet
/// and submits a pending stock adjustment for manager/admin approval.
class ProductsTab extends ConsumerWidget {
  final bool canManage;
  const ProductsTab({super.key, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(productsProvider),
      child: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return const Center(child: Text('No products yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.only(
              bottom: LayoutConstants.navBarClearance,
            ),
            itemCount: products.length,
            itemBuilder: (context, i) =>
                _ProductTile(product: products[i], canManage: canManage),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load products: $e')),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final bool canManage;
  const _ProductTile({required this.product, required this.canManage});

  Color? _stockColor(BuildContext context, int qty) {
    if (qty == 0) return Theme.of(context).colorScheme.error;
    if (qty <= 10) return Colors.orange.shade700;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: ProductAvatar(image: product.image),
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
              canManage: canManage,
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
  final bool canManage;
  final Color? stockColor;
  const _SizeRow({
    required this.product,
    required this.size,
    required this.canManage,
    required this.stockColor,
  });

  @override
  ConsumerState<_SizeRow> createState() => _SizeRowState();
}

class _SizeRowState extends ConsumerState<_SizeRow> {
  bool _busy = false;

  Future<void> _submit(
    int changeQty, {
    required String reason,
    String? note,
  }) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(productsApiProvider)
          .submitStockAdjustment(
            productId: widget.product.id,
            size: widget.size.size,
            changeQty: changeQty,
            reason: reason,
            note: note,
          );
      Haptics.tap();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted — pending approval')),
        );
      }
    } on ApiException catch (e) {
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAdjustSheet() async {
    final result = await showModalBottomSheet<_AdjustInput>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _AdjustStockSheet(product: widget.product, size: widget.size),
    );
    if (result == null) return;
    await _submit(result.delta, reason: result.reason, note: result.note);
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
                Text(
                  '${widget.size.stockQty}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.stockColor,
                  ),
                ),
                if (widget.canManage) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Adjust stock',
                    onPressed: _openAdjustSheet,
                  ),
                ],
              ],
            ),
    );
  }
}

class _AdjustInput {
  final int delta;
  final String reason;
  final String? note;
  _AdjustInput(this.delta, this.reason, this.note);
}

/// Small locked/disabled-looking icon slot that takes the place of a
/// stepper button when that direction isn't valid for the selected reason.
/// Keeps the row visually balanced instead of leaving empty space.
class _LockedDirectionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  const _LockedDirectionIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: color.withValues(alpha: 0.45), size: 18),
      ),
    );
  }
}

class _AdjustStockSheet extends StatefulWidget {
  final Product product;
  final ProductSize size;
  const _AdjustStockSheet({required this.product, required this.size});

  @override
  State<_AdjustStockSheet> createState() => _AdjustStockSheetState();
}

class _AdjustStockSheetState extends State<_AdjustStockSheet> {
  int _delta = 0;
  final _deltaCtrl = TextEditingController(text: '0');
  final _noteCtrl = TextEditingController();
  String _reason = productStockAdjustReasons.first;

  @override
  void dispose() {
    _deltaCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _isRestock => _reason == 'restock';
  bool get _isDamaged => _reason == 'damaged';

  // Restock is always +, damaged is always -, correction keeps sign.
  int _signedFor(String reason, int magnitude) {
    if (reason == 'restock') return magnitude.abs();
    if (reason == 'damaged') return -magnitude.abs();
    return magnitude;
  }

  void _step(int by) {
    setState(() {
      _delta += by;
      if (_isRestock && _delta < 0) _delta = 0;
      if (_isDamaged && _delta > 0) _delta = 0;
      _deltaCtrl.text = _delta.toString();
    });
    Haptics.tap();
  }

  void _onReasonSelected(String reason) {
    setState(() {
      _reason = reason;
      _delta = _signedFor(reason, _delta.abs());
      _deltaCtrl.text = _delta.toString();
    });
  }

  void _onFieldChanged(String v) {
    final parsed = int.tryParse(v) ?? 0;
    setState(() => _delta = _signedFor(_reason, parsed.abs()));
  }

  String get _helperText {
    if (_isRestock) return 'Restocking only adds to stock.';
    if (_isDamaged) return 'Damaged/lost only removes from stock.';
    return 'Corrections can increase or decrease stock.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final projected = widget.size.stockQty + _delta;
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
                'Adjust — ${widget.product.name} (${widget.size.size})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Current: ${widget.size.stockQty}  →  New: $projected',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _isRestock
                      ? const _LockedDirectionIcon(
                          icon: Icons.remove_circle_outline,
                          color: Color(0xFFC62828),
                          tooltip: 'Not available for restock',
                        )
                      : IconButton.filledTonal(
                          onPressed: () => _step(-1),
                          icon: const Icon(Icons.remove),
                        ),
                  Expanded(
                    child: TextField(
                      controller: _deltaCtrl,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.numberWithOptions(
                        signed: _reason == 'correction',
                      ),
                      onChanged: _onFieldChanged,
                      decoration: const InputDecoration(labelText: 'Change'),
                    ),
                  ),
                  _isDamaged
                      ? const _LockedDirectionIcon(
                          icon: Icons.add_circle_outline,
                          color: Color(0xFF2E7D32),
                          tooltip: 'Not available for damaged/lost',
                        )
                      : IconButton.filledTonal(
                          onPressed: () => _step(1),
                          icon: const Icon(Icons.add),
                        ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _helperText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Text('Reason', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: productStockAdjustReasons
                    .map(
                      (r) => ChoiceChip(
                        label: Text(r),
                        selected: _reason == r,
                        onSelected: (_) => _onReasonSelected(r),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _delta == 0
                    ? null
                    : () => Navigator.pop(
                        context,
                        _AdjustInput(_delta, _reason, _noteCtrl.text.trim()),
                      ),
                child: const Text('Submit for Approval'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
