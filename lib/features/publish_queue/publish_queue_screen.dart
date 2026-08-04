import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'publish_queue_api.dart';
import 'publish_queue_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/tap_scale.dart';
import '../../shared/widgets/staggered_fade_in.dart';

/// Thin standalone wrapper for the /publish-queue route — mirrors the
/// DbExplorerScreen/DbExplorerView split so PublishQueueView can also be
/// embedded as a tab inside SiteScreen without a duplicate AppBar.
class PublishQueueScreen extends StatelessWidget {
  const PublishQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publish Queue')),
      body: const PublishQueueView(),
    );
  }
}

class _SourceTypeMeta {
  final String label;
  final IconData icon;
  final Color color;
  const _SourceTypeMeta(this.label, this.icon, this.color);
}

const _sourceTypeMeta = <String, _SourceTypeMeta>{
  'product_core': _SourceTypeMeta(
    'Catalog Changes',
    Icons.edit_note_outlined,
    AppColors.turmeric,
  ),
  'review': _SourceTypeMeta(
    'New Reviews',
    Icons.rate_review_outlined,
    Color(0xFF3D6B57),
  ),
  'product_create': _SourceTypeMeta(
    'Products Added',
    Icons.add_box_outlined,
    Color(0xFF2E7D32),
  ),
  'product_delete': _SourceTypeMeta(
    'Products Removed',
    Icons.remove_circle_outline,
    Color(0xFFC62828),
  ),
};

class PublishQueueView extends ConsumerStatefulWidget {
  const PublishQueueView({super.key});

  @override
  ConsumerState<PublishQueueView> createState() => _PublishQueueViewState();
}

class _PublishQueueViewState extends ConsumerState<PublishQueueView> {
  bool _publishing = false;

  Future<void> _confirmAndPublish(int pendingCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Publish changes?'),
        content: Text(
          'This will publish $pendingCount change${pendingCount == 1 ? '' : 's'} to the '
          'live site. This triggers a real deploy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.maroon),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _publishing = true);
    try {
      final result = await ref.read(publishQueueApiProvider).runPublish();
      Haptics.success();
      ref.invalidate(publishQueueProvider);
      if (mounted) {
        final count = result.itemCount ?? pendingCount;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.published
                  ? 'Published $count change${count == 1 ? '' : 's'}'
                  : (result.message ?? 'Nothing to publish.'),
            ),
          ),
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
      if (mounted) setState(() => _publishing = false);
    }
  }

  String _relativeTime(String raw) {
    if (raw.isEmpty) return '';
    var iso = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
    if (!iso.endsWith('Z') && !iso.contains('+')) iso += 'Z';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return raw;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(publishQueueProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(publishQueueProvider),
      child: queueAsync.when(
        data: (state) {
          final grouped = <String, List<SyncQueueItem>>{};
          for (final item in state.pending) {
            grouped.putIfAbsent(item.sourceType, () => []).add(item);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              LayoutConstants.navBarClearance,
            ),
            children: [
              _HeroCard(
                pendingCount: state.pendingCount,
                publishing: _publishing,
                onPublish: state.pendingCount == 0 || _publishing
                    ? null
                    : () => _confirmAndPublish(state.pendingCount),
              ),
              if (state.lastBatch != null) ...[
                const SizedBox(height: 16),
                _LastBatchCard(
                  batch: state.lastBatch!,
                  relativeTime: _relativeTime,
                ),
              ],
              const SizedBox(height: 20),
              for (final entry in _sourceTypeMeta.entries)
                if (grouped[entry.key]?.isNotEmpty ?? false) ...[
                  _SectionHeader(
                    label: entry.value.label,
                    icon: entry.value.icon,
                    color: entry.value.color,
                    count: grouped[entry.key]!.length,
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < grouped[entry.key]!.length; i++)
                    StaggeredFadeIn(
                      key: ValueKey('sync_${grouped[entry.key]![i].id}'),
                      index: i,
                      child: _QueueItemTile(
                        item: grouped[entry.key]![i],
                        color: entry.value.color,
                        relativeTime: _relativeTime,
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Could not load publish queue: $e')),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final int pendingCount;
  final bool publishing;
  final VoidCallback? onPublish;
  const _HeroCard({
    required this.pendingCount,
    required this.publishing,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final calm = pendingCount == 0;
    final accent = calm ? const Color(0xFF2E7D32) : AppColors.maroon;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.16),
            accent.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(
            calm ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
            size: 40,
            color: accent,
          ),
          const SizedBox(height: 12),
          Text(
            calm
                ? 'All caught up'
                : '$pendingCount change${pendingCount == 1 ? '' : 's'} pending',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            calm
                ? 'Nothing waiting to go live.'
                : 'Saved here, not yet on the live site.',
            style: TextStyle(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (!calm) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon,
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: onPublish,
                icon: publishing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.publish),
                label: Text(
                  publishing
                      ? 'Publishing…'
                      : 'Publish $pendingCount Change${pendingCount == 1 ? '' : 's'}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LastBatchCard extends StatelessWidget {
  final LastSyncBatch batch;
  final String Function(String) relativeTime;
  const _LastBatchCard({required this.batch, required this.relativeTime});

  @override
  Widget build(BuildContext context) {
    final failed = batch.failed;
    final color = failed ? AppColors.paprika : const Color(0xFF2E7D32);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: failed ? 0.4 : 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            failed ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  failed
                      ? 'Last publish failed'
                      : 'Last published ${relativeTime(batch.completedAt ?? batch.startedAt ?? '')}',
                  style: TextStyle(fontWeight: FontWeight.w600, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  '${batch.itemCount} item${batch.itemCount == 1 ? '' : 's'}'
                  '${batch.triggeredByName != null ? ' · by ${batch.triggeredByName}' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (failed && batch.errorMessage != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    batch.errorMessage!,
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int count;
  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          '$label ($count)',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _QueueItemTile extends StatelessWidget {
  final SyncQueueItem item;
  final Color color;
  final String Function(String) relativeTime;
  const _QueueItemTile({
    required this.item,
    required this.color,
    required this.relativeTime,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TapScale(
      scaleDown: 0.99,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.summary,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (item.productSlug != null &&
                          item.productSlug!.isNotEmpty)
                        item.productSlug!,
                      if (item.createdByName != null)
                        'by ${item.createdByName}',
                      relativeTime(item.createdAt),
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
