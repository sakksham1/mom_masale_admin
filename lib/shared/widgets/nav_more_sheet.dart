// lib/shared/widgets/nav_more_sheet.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'tap_scale.dart';
import '../../core/utils/haptics.dart';

class NavMoreItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const NavMoreItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

/// Animated "more" popup for the floating nav bar — used when a role has
/// too many sections to fit as direct tabs (currently: admin). Pops up
/// just above the nav bar with a soft blur scrim behind it; each item
/// pops in with a slight stagger.
class NavMoreSheet {
  NavMoreSheet._();

  static void show(
    BuildContext context, {
    required List<NavMoreItem> items,
    required double bottomOffset,
    VoidCallback? onDismissed,
  }) {
    late OverlayEntry entry;
    final overlayState = Overlay.of(context);

    entry = OverlayEntry(
      builder: (_) => _NavMoreOverlay(
        items: items,
        bottomOffset: bottomOffset,
        onClose: () {
          entry.remove();
          onDismissed?.call();
        },
      ),
    );

    overlayState.insert(entry);
  }
}

class _NavMoreOverlay extends StatefulWidget {
  final List<NavMoreItem> items;
  final double bottomOffset;
  final VoidCallback onClose;
  const _NavMoreOverlay({
    required this.items,
    required this.bottomOffset,
    required this.onClose,
  });

  @override
  State<_NavMoreOverlay> createState() => _NavMoreOverlayState();
}

class _NavMoreOverlayState extends State<_NavMoreOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 180),
  )..forward();

  bool _closing = false;

  void _dismiss() {
    if (_closing) return;
    _closing = true;
    _controller.reverse().then((_) => widget.onClose());
  }

  void _handleItemTap(NavMoreItem item) {
    Haptics.tap();
    item.onTap();
    _dismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _dismiss,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 4 * _controller.value,
                    sigmaY: 4 * _controller.value,
                  ),
                  child: Container(
                    color: Colors.black.withValues(
                      alpha: 0.35 * _controller.value,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: widget.bottomOffset + bottomInset,
              child: IgnorePointer(
                ignoring: _controller.value < 0.5,
                child: Opacity(
                  opacity: _controller.value.clamp(0, 1),
                  child: Transform.translate(
                    offset: Offset(0, 24 * (1 - t)),
                    child: Transform.scale(
                      scale: 0.92 + 0.08 * t,
                      alignment: Alignment.bottomCenter,
                      child: _MoreCard(
                        items: widget.items,
                        progress: _controller.value,
                        onItemTap: _handleItemTap,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MoreCard extends StatelessWidget {
  final List<NavMoreItem> items;
  final double progress;
  final ValueChanged<NavMoreItem> onItemTap;
  const _MoreCard({
    required this.items,
    required this.progress,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < items.length; i++)
                    _PoppingItem(
                      item: items[i],
                      index: i,
                      progress: progress,
                      onTap: () => onItemTap(items[i]),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PoppingItem extends StatelessWidget {
  final NavMoreItem item;
  final int index;
  final double progress;
  final VoidCallback onTap;
  const _PoppingItem({
    required this.item,
    required this.index,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Each item starts its pop-in slightly after the previous one.
    final start = 0.15 * index;
    final localT = ((progress - start) / (1 - start)).clamp(0.0, 1.0);
    final scale = Curves.elasticOut.transform(localT);

    return Opacity(
      opacity: localT,
      child: Transform.scale(
        scale: scale <= 0 ? 0.01 : scale,
        child: TapScale(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        item.color.withValues(alpha: 0.22),
                        item.color.withValues(alpha: 0.08),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: item.color.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(item.icon, color: item.color, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
