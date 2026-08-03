import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'my_requests_api.dart';
import 'my_requests_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/utils/haptics.dart';
import '../warehouse/raw_materials_api.dart' show formatQty;

class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(myRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Requests')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myRequestsProvider),
        child: requestsAsync.when(
          data: (r) {
            if (r.packaging.isEmpty &&
                r.rawMaterial.isEmpty &&
                r.productStock.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: Center(
                      child: Text("You haven't submitted anything yet."),
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
                if (r.packaging.isNotEmpty) ...[
                  const _SectionHeader('Packaging Reports'),
                  ...r.packaging.map(
                    (p) => _RequestTile(
                      title: '${p.productName} (${p.size}) × ${p.qty}',
                      subtitle: p.reportDate,
                      status: p.status,
                      onCancel: p.status == 'pending'
                          ? () => _cancel(context, ref, 'packaging', p.id)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (r.rawMaterial.isNotEmpty) ...[
                  const _SectionHeader('Raw Material Adjustments'),
                  ...r.rawMaterial.map(
                    (m) => _RequestTile(
                      title: m.inputAmount != null && m.inputUnit != null
                          ? '${m.materialName}  ${m.inputAmount! > 0 ? '+' : ''}${m.inputAmount} ${m.inputUnit}'
                          : '${m.materialName}  ${m.delta > 0 ? '+' : ''}${m.delta}',
                      subtitle:
                          'Reason: ${m.reason}${m.note != null && m.note!.isNotEmpty ? ' · ${m.note}' : ''}',
                      status: m.status,
                      onCancel: m.status == 'pending'
                          ? () => _cancel(context, ref, 'raw_material', m.id)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (r.productStock.isNotEmpty) ...[
                  const _SectionHeader('Product Stock Adjustments'),
                  ...r.productStock.map(
                    (s) => _RequestTile(
                      title:
                          '${s.productName} (${s.size})  ${s.changeQty > 0 ? '+' : ''}${s.changeQty}',
                      subtitle:
                          'Reason: ${s.reason}${s.note != null && s.note!.isNotEmpty ? ' · ${s.note}' : ''}',
                      status: s.status,
                      onCancel: s.status == 'pending'
                          ? () => _cancel(context, ref, 'product_stock', s.id)
                          : null,
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('Could not load your requests: $e')),
        ),
      ),
    );
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    String type,
    int id,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Withdraw this request?'),
        content: const Text(
          'This removes it from the approval queue. You can resubmit anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(myRequestsApiProvider).cancel(type: type, id: id);
      Haptics.tap();
      ref.invalidate(myRequestsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Request withdrawn')));
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

class _RequestTile extends StatelessWidget {
  final String title, subtitle, status;
  final VoidCallback? onCancel;
  const _RequestTile({
    required this.title,
    required this.subtitle,
    required this.status,
    this.onCancel,
  });

  ({Color color, IconData icon}) _visual() {
    switch (status) {
      case 'approved':
        return (
          color: const Color(0xFF2E7D32),
          icon: Icons.check_circle_outline,
        );
      case 'rejected':
        return (color: const Color(0xFFC62828), icon: Icons.cancel_outlined);
      default:
        return (color: AppColors.turmeric, icon: Icons.hourglass_empty);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _visual();
    return Card(
      child: ListTile(
        leading: Icon(v.icon, color: v.color),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: onCancel != null
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Withdraw',
                onPressed: onCancel,
              )
            : Chip(
                label: Text(status, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: v.color.withValues(alpha: 0.15),
                labelStyle: TextStyle(color: v.color),
              ),
      ),
    );
  }
}
