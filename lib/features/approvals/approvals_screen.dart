import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'approvals_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/constants/layout_constants.dart';

class ApprovalsScreen extends ConsumerWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(approvalsQueueProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Approvals')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(approvalsQueueProvider),
        child: queueAsync.when(
          data: (queue) {
            if (queue.isEmpty) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  LayoutConstants.navBarClearance,
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('Nothing pending. All caught up.'),
                    ),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                LayoutConstants.navBarClearance,
              ),
              children: [
                if (queue.rawMaterial.isNotEmpty) ...[
                  _SectionHeader('Raw Material Adjustments'),
                  ...queue.rawMaterial.map(
                    (r) => _DecisionTile(
                      title:
                          '${r.materialName}  ${r.delta > 0 ? '+' : ''}${r.delta}',
                      subtitle:
                          'Reason: ${r.reason}'
                          '${r.note != null && r.note!.isNotEmpty ? ' · ${r.note}' : ''}'
                          ' · by ${r.requestedByName}',
                      onDecide: (decision) =>
                          _decide(context, ref, 'raw_material', r.id, decision),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (queue.productStock.isNotEmpty) ...[
                  _SectionHeader('Product Stock Adjustments'),
                  ...queue.productStock.map(
                    (s) => _DecisionTile(
                      title:
                          '${s.productName} (${s.size})  ${s.changeQty > 0 ? '+' : ''}${s.changeQty}',
                      subtitle:
                          'Reason: ${s.reason}'
                          '${s.note != null && s.note!.isNotEmpty ? ' · ${s.note}' : ''}'
                          ' · by ${s.requestedByName}',
                      onDecide: (decision) => _decide(
                        context,
                        ref,
                        'product_stock',
                        s.id,
                        decision,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (queue.packaging.isNotEmpty) ...[
                  _SectionHeader('Packaging Reports'),
                  ...queue.packaging.map(
                    (p) => _DecisionTile(
                      title: '${p.productSlug} (${p.size}) × ${p.qty}',
                      subtitle:
                          'Reported by ${p.requestedByName} on ${p.reportDate}',
                      onDecide: (decision) =>
                          _decide(context, ref, 'packaging', p.id, decision),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (queue.productCore.isNotEmpty) ...[
                  _SectionHeader('Product Changes'),
                  ...queue.productCore.map(
                    (c) => _DecisionTile(
                      title: c.field == 'name'
                          ? 'Rename → ${c.payload['name']}'
                          : 'Price change — ${c.payload['size']}: ₹${c.payload['price']}',
                      subtitle:
                          '${c.productSlug ?? 'product'} · by ${c.requestedByName}',
                      onDecide: (decision) =>
                          _decide(context, ref, 'product_core', c.id, decision),
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load approvals: $e')),
        ),
      ),
    );
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    String type,
    int id,
    String decision,
  ) async {
    try {
      await ref
          .read(approvalsApiProvider)
          .decide(type: type, id: id, decision: decision);
      ref.invalidate(approvalsQueueProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decision == 'approved' ? 'Approved' : 'Rejected'),
          ),
        );
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _DecisionTile extends StatefulWidget {
  final String title, subtitle;
  final Future<void> Function(String decision) onDecide;
  const _DecisionTile({
    required this.title,
    required this.subtitle,
    required this.onDecide,
  });

  @override
  State<_DecisionTile> createState() => _DecisionTileState();
}

class _DecisionTileState extends State<_DecisionTile> {
  bool _busy = false;

  Future<void> _tap(String decision) async {
    setState(() => _busy = true);
    await widget.onDecide(decision);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(widget.title),
        subtitle: Text(widget.subtitle),
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
                    icon: Icon(
                      Icons.check_circle,
                      color: Colors.green.shade600,
                    ),
                    tooltip: 'Approve',
                    onPressed: () => _tap('approved'),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.cancel,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    tooltip: 'Reject',
                    onPressed: () => _tap('rejected'),
                  ),
                ],
              ),
      ),
    );
  }
}
