import 'dart:ui';
import 'package:flutter/material.dart';

/// Transient centered confirmation overlay — a soft blurred scrim behind a
/// rounded card with an animated check badge and message, then fades itself
/// out. Call after actions that deserve more delight than a snackbar alone.
class SuccessPulse {
  SuccessPulse._();

  static Future<void> show(
    BuildContext context,
    String message, {
    IconData icon = Icons.check_rounded,
    Color? accentColor,
  }) async {
    final overlayState = Overlay.of(context);
    final scheme = Theme.of(context).colorScheme;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _SuccessPulseOverlay(
        message: message,
        icon: icon,
        accentColor: accentColor ?? const Color(0xFF2E7D32),
        cardColor: scheme.surfaceContainerHigh,
        textColor: scheme.onSurface,
      ),
    );
    overlayState.insert(entry);
    await Future.delayed(const Duration(milliseconds: 1500));
    entry.remove();
  }
}

class _SuccessPulseOverlay extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color accentColor;
  final Color cardColor;
  final Color textColor;
  const _SuccessPulseOverlay({
    required this.message,
    required this.icon,
    required this.accentColor,
    required this.cardColor,
    required this.textColor,
  });

  @override
  State<_SuccessPulseOverlay> createState() => _SuccessPulseOverlayState();
}

class _SuccessPulseOverlayState extends State<_SuccessPulseOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final popT = (t / 0.3).clamp(0.0, 1.0);
          final scale = Curves.easeOutBack.transform(popT);
          final fadeOut = t < 0.8 ? 1.0 : (1 - (t - 0.8) / 0.2).clamp(0.0, 1.0);
          final blur = 6 * popT * fadeOut;
          final checkT = ((t - 0.15) / 0.35).clamp(0.0, 1.0);

          return Opacity(
            opacity: fadeOut,
            child: Stack(
              children: [
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.18 * popT),
                    ),
                  ),
                ),
                Center(
                  child: Transform.scale(
                    scale: scale <= 0 ? 0.01 : scale,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 280),
                      padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
                      decoration: BoxDecoration(
                        color: widget.cardColor,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 32,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  widget.accentColor,
                                  widget.accentColor.withValues(alpha: 0.75),
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.accentColor.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Opacity(
                                opacity: checkT,
                                child: Transform.scale(
                                  scale: 0.6 + 0.4 * checkT,
                                  child: Icon(
                                    widget.icon,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: widget.textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              height: 1.35,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
