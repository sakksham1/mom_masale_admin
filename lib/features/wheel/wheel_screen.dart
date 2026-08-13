// lib/features/wheel/wheel_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'wheel_api.dart';
import 'wheel_provider.dart';
import 'wheel_mode_edit_screen.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/layout_constants.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/tap_scale.dart';
import '../../shared/widgets/staggered_fade_in.dart';

/// Admin/manager screen for the homepage spice wheel — lists every "mode"
/// (a full tap-cycle rotation, e.g. "Shop by Category") with its wedge count
/// and active state. Tapping a mode opens WheelModeEditScreen, which handles
/// both the mode's own fields and its wedges in one place.
class WheelScreen extends ConsumerStatefulWidget {
  const WheelScreen({super.key});

  @override
  ConsumerState<WheelScreen> createState() => _WheelScreenState();
}

class _WheelScreenState extends ConsumerState<WheelScreen> {
  Future<void> _openNew() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const WheelModeEditScreen(mode: null)),
    );
    ref.invalidate(wheelModesProvider);
  }

  Future<void> _openEdit(WheelMode mode) async {
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => WheelModeEditScreen(mode: mode)));
    ref.invalidate(wheelModesProvider);
  }

  Future<void> _toggleActive(WheelMode mode) async {
    try {
      await ref.read(wheelApiProvider).updateMode(mode.id, {
        'isActive': !mode.isActive,
      });
      Haptics.success();
      ref.invalidate(wheelModesProvider);
    } on ApiException catch (e) {
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final modesAsync = ref.watch(wheelModesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Spice Wheel')),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
          bottom: LayoutConstants.fabScaffoldExtraPadding,
        ),
        child: FloatingActionButton.extended(
          onPressed: _openNew,
          icon: const Icon(Icons.add),
          label: const Text('New Mode'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(wheelModesProvider),
        child: modesAsync.when(
          data: (modes) {
            if (modes.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 72),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.donut_large_outlined,
                            size: 40,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No wheel modes yet.',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "New Mode" to build the homepage wheel.',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            final sorted = [...modes]
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            return ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                LayoutConstants.navBarClearance +
                    LayoutConstants.fabScaffoldExtraPadding,
              ),
              children: [
                _IntroCard(
                  activeCount: modes.where((m) => m.isActive).length,
                  totalCount: modes.length,
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < sorted.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: StaggeredFadeIn(
                      key: ValueKey('wheel_mode_fade_${sorted[i].id}'),
                      index: i,
                      child: _ModeCard(
                        key: ValueKey('wheel_mode_${sorted[i].id}'),
                        mode: sorted[i],
                        onTap: () => _openEdit(sorted[i]),
                        onToggle: () => _toggleActive(sorted[i]),
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('Could not load wheel modes: $e')),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final int activeCount, totalCount;
  const _IntroCard({required this.activeCount, required this.totalCount});

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
            AppColors.turmeric.withValues(alpha: 0.18),
            AppColors.maroon.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.turmeric.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.turmeric.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.donut_large_outlined,
              color: AppColors.maroon,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Homepage Spice Wheel',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$activeCount of $totalCount mode${totalCount == 1 ? '' : 's'} active in the tap-cycle',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends ConsumerWidget {
  final WheelMode mode;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  const _ModeCard({
    super.key,
    required this.mode,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final itemsAsync = ref.watch(wheelItemsProvider(mode.id));
    final wedgeCount = itemsAsync.maybeWhen(
      data: (items) => items.length,
      orElse: () => null,
    );

    return TapScale(
      scaleDown: 0.985,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: mode.isActive
                ? AppColors.turmeric.withValues(alpha: 0.5)
                : scheme.outlineVariant.withValues(alpha: 0.4),
            width: mode.isActive ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.maroon.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                mode.centerGlyph,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.displayLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    wedgeCount == null
                        ? mode.key
                        : '${mode.key} · $wedgeCount wedge${wedgeCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                      fontFamily: 'IBMPlexMono',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Switch(value: mode.isActive, onChanged: (_) => onToggle()),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
