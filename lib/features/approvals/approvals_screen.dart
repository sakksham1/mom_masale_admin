import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'approvals_provider.dart';
import '../../core/auth/user_role.dart';
import '../../core/network/api_client_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/constants/layout_constants.dart';

class ApprovalsScreen extends ConsumerWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(approvalsQueueProvider);
    final role = ref.watch(authControllerProvider).role;
    // Catalog changes go straight to the live site, so only an admin can
    // approve/reject them here — the backend enforces this too, this just
    // avoids showing a manager buttons that would 403.
    final canApproveCatalog = role == UserRole.admin;

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
                if (queue.productCore.isNotEmpty) ...[
                  _SectionHeader('Product Catalog Changes'),
                  ...queue.productCore.map(
                    (c) => _DecisionTile(
                      title: c.productSlug ?? 'product',
                      subtitle: '${c.summary} · by ${c.requestedByName}',
                      canDecide: canApproveCatalog,
                      lockedReason: 'Awaiting admin approval',
                      onDecide: (decision) =>
                          _decide(context, ref, 'product_core', c.id, decision),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
  final bool canDecide;
  final String? lockedReason;
  const _DecisionTile({
    required this.title,
    required this.subtitle,
    required this.onDecide,
    this.canDecide = true,
    this.lockedReason,
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
        trailing: !widget.canDecide
            ? Chip(
                label: Text(
                  widget.lockedReason ?? 'Pending',
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )
            : _busy
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
