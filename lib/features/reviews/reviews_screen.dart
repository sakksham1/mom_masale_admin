import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'reviews_api.dart';
import 'reviews_provider.dart';
import '../../core/auth/user_role.dart';
import '../../core/network/api_client_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/success_pulse.dart';
import '../../shared/widgets/tap_scale.dart';

/// Approval queue for customer product reviews. Two tabs: Pending (with
/// actions) and Approved (read-only history). Decide is admin-only on the
/// backend — manager sees everything but gets a locked chip instead of
/// buttons, same convention as the Product Catalog approvals.
class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingReviewsProvider);
    final pendingCount = pendingAsync.maybeWhen(
      data: (r) => r.length,
      orElse: () => 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews'),
        bottom: TabBar(
          controller: _controller,
          tabs: [
            Tab(text: pendingCount > 0 ? 'Pending ($pendingCount)' : 'Pending'),
            const Tab(text: 'Approved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: const [
          _ReviewsList(status: 'pending'),
          _ReviewsList(status: 'approved'),
        ],
      ),
    );
  }
}

class _ReviewsList extends ConsumerWidget {
  final String status;
  const _ReviewsList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = status == 'pending'
        ? pendingReviewsProvider
        : approvedReviewsProvider;
    final reviewsAsync = ref.watch(provider);
    final role = ref.watch(authControllerProvider).role;
    final canDecide = role == UserRole.admin;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(provider),
      child: reviewsAsync.when(
        data: (reviews) {
          if (reviews.isEmpty) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 64),
                  child: Center(
                    child: Text(
                      status == 'pending'
                          ? 'No reviews awaiting approval.'
                          : 'No approved reviews yet.',
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              LayoutConstants.navBarClearance,
            ),
            itemCount: reviews.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReviewCard(
                review: reviews[i],
                showActions: status == 'pending',
                canDecide: canDecide,
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load reviews: $e')),
      ),
    );
  }
}

class _ReviewCard extends ConsumerStatefulWidget {
  final ReviewItem review;
  final bool showActions;
  final bool canDecide;
  const _ReviewCard({
    required this.review,
    required this.showActions,
    required this.canDecide,
  });

  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<_ReviewCard> {
  bool _expanded = false;
  bool _busy = false;

  Future<void> _decide(String decision) async {
    String? reason;
    if (decision == 'rejected') {
      reason = await _askRejectReason();
      if (reason == null) return; // cancelled
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(reviewsApiProvider)
          .decide(
            reviewId: widget.review.id,
            decision: decision,
            reason: reason,
          );
      Haptics.success();
      ref.invalidate(pendingReviewsProvider);
      ref.invalidate(approvedReviewsProvider);
      if (mounted) {
        await SuccessPulse.show(
          context,
          decision == 'approved' ? 'Review approved' : 'Review rejected',
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

  Future<String?> _askRejectReason() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject this review?'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'e.g. spam, offensive language',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(
              dialogContext,
              ctrl.text.trim().isEmpty ? '' : ctrl.text.trim(),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _openImage(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(dialogContext),
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final scheme = Theme.of(context).colorScheme;
    final bodyOverflows = r.body.length > 220;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.productName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _RatingStars(rating: r.rating),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: Text(
                  r.userName,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (r.verifiedPurchase) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Verified purchase',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                r.createdAt.length >= 10
                    ? r.createdAt.substring(0, 10)
                    : r.createdAt,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          if (r.title != null && r.title!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(r.title!, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 6),
          Text(
            r.body,
            maxLines: _expanded ? null : 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              color: scheme.onSurface.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          if (bodyOverflows)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'Show less' : 'Read more',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
          if (r.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: r.images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => TapScale(
                  onTap: () => _openImage(r.images[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      r.images[i],
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 64,
                        height: 64,
                        color: scheme.surfaceContainerHighest,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (widget.showActions) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (!widget.canDecide)
              const Align(
                alignment: Alignment.centerRight,
                child: Chip(
                  label: Text(
                    'Admin review required',
                    style: TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
            else if (_busy)
              const Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(
                        color: scheme.error.withValues(alpha: 0.5),
                      ),
                    ),
                    onPressed: () => _decide('rejected'),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                    ),
                    onPressed: () => _decide('approved'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  final int rating;
  const _RatingStars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 16,
          color: AppColors.turmeric,
        ),
      ),
    );
  }
}
