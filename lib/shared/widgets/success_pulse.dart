import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Transient full-screen overlay: a circle pops in with a checkmark and a
/// short message, then fades itself out. Call after actions that deserve
/// more delight than a snackbar alone — bulk submits, approvals, etc.
class SuccessPulse {
  SuccessPulse._();

  static Future<void> show(BuildContext context, String message) async {
    final overlayState = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _SuccessPulseOverlay(message: message),
    );
    overlayState.insert(entry);
    await Future.delayed(const Duration(milliseconds: 1300));
    entry.remove();
  }
}

class _SuccessPulseOverlay extends StatefulWidget {
  final String message;
  const _SuccessPulseOverlay({required this.message});

  @override
  State<_SuccessPulseOverlay> createState() => _SuccessPulseOverlayState();
}

class _SuccessPulseOverlayState extends State<_SuccessPulseOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final scale = Curves.elasticOut.transform(
              (t / 0.35).clamp(0, 1).toDouble(),
            );
            final opacity = t < 0.75
                ? 1.0
                : (1 - (t - 0.75) / 0.25).clamp(0.0, 1.0);
            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.charcoal.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
