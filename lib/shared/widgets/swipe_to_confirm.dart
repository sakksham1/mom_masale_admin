import 'package:flutter/material.dart';
import '../../core/utils/haptics.dart';

/// A "slide to confirm" control. Drag the thumb to the far end to trigger
/// [onConfirmed]; release early and it snaps back to the start. Used for
/// any action that should require a deliberate, hard-to-mis-tap gesture
/// (e.g. role reassignment) rather than a single button press.
class SwipeToConfirm extends StatefulWidget {
  final String label;
  final String confirmedLabel;
  final Color color;
  final VoidCallback onConfirmed;

  const SwipeToConfirm({
    super.key,
    required this.label,
    this.confirmedLabel = 'Confirmed',
    required this.color,
    required this.onConfirmed,
  });

  @override
  State<SwipeToConfirm> createState() => _SwipeToConfirmState();
}

class _SwipeToConfirmState extends State<SwipeToConfirm>
    with SingleTickerProviderStateMixin {
  double _dragX = 0;
  bool _confirmed = false;
  bool _dragging = false;

  late final AnimationController _snapController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<double>? _snapAnim;

  static const double _thumbSize = 52;
  static const double _trackHeight = 60;
  static const double _trackPadding = 4;

  void _onDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (_confirmed) return;
    setState(() {
      _dragX = (_dragX + details.delta.dx).clamp(0, maxDrag);
    });
  }

  void _onDragEnd(double maxDrag) {
    if (_confirmed || maxDrag <= 0) return;
    if (_dragX >= maxDrag * 0.82) {
      setState(() {
        _dragX = maxDrag;
        _confirmed = true;
      });
      Haptics.success();
      Future.delayed(const Duration(milliseconds: 160), widget.onConfirmed);
    } else {
      _snapAnim =
          Tween<double>(begin: _dragX, end: 0).animate(
            CurvedAnimation(parent: _snapController, curve: Curves.easeOut),
          )..addListener(() {
            if (mounted) setState(() => _dragX = _snapAnim!.value);
          });
      _snapController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = (constraints.maxWidth - _thumbSize - _trackPadding * 2)
            .clamp(0.0, double.infinity);
        final progress = maxDrag <= 0
            ? 0.0
            : (_dragX / maxDrag).clamp(0.0, 1.0);

        return Container(
          height: _trackHeight,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(_trackHeight / 2),
            border: Border.all(color: widget.color.withValues(alpha: 0.3)),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              AnimatedContainer(
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                margin: const EdgeInsets.all(_trackPadding),
                width: (_dragX + _thumbSize).clamp(
                  _thumbSize,
                  constraints.maxWidth - _trackPadding * 2,
                ),
                height: _trackHeight - _trackPadding * 2,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(
                    (_trackHeight - _trackPadding * 2) / 2,
                  ),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: (1 - progress * 1.4).clamp(0.0, 1.0),
                  child: Text(
                    _confirmed ? widget.confirmedLabel : widget.label,
                    style: TextStyle(
                      color: widget.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: _trackPadding + _dragX,
                child: GestureDetector(
                  onHorizontalDragStart: (_) =>
                      setState(() => _dragging = true),
                  onHorizontalDragUpdate: (d) => _onDragUpdate(d, maxDrag),
                  onHorizontalDragEnd: (_) {
                    setState(() => _dragging = false);
                    _onDragEnd(maxDrag);
                  },
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      _confirmed ? Icons.check : Icons.chevron_right,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
