import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// The Mom Masale stamp mark: concentric rings with a dotted "peppercorn"
/// ring and an "MM" monogram, echoing the embossed lid-stamp on a spice tin.
/// Used on the login screen and anywhere a compact brand mark is needed.
///
/// If you have a real logo asset (PNG/SVG) from a designer, swap this out
/// for an Image.asset/SvgPicture — this is a code-drawn placeholder that
/// needs no image file and matches the brand palette exactly.
class BrandLogo extends StatelessWidget {
  final double size;
  final Color? ringColor;
  final Color? monogramColor;

  const BrandLogo({
    super.key,
    this.size = 96,
    this.ringColor,
    this.monogramColor,
  });

  @override
  Widget build(BuildContext context) {
    final ring = ringColor ?? AppColors.turmeric;
    final mono = monogramColor ?? AppColors.parchment;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StampPainter(ringColor: ring),
        child: Center(
          child: Text(
            'MM',
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontSize: size * 0.32,
              fontWeight: FontWeight.w600,
              color: mono,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  final Color ringColor;
  _StampPainter({required this.ringColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final fill = Paint()..color = AppColors.maroon;
    canvas.drawCircle(center, radius, fill);

    final outerRing = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.045;
    canvas.drawCircle(center, radius * 0.86, outerRing);

    // Peppercorn dot ring — the one decorative flourish, kept singular.
    final dotPaint = Paint()..color = ringColor;
    const dotCount = 16;
    final dotRadius = radius * 0.035;
    final dotOrbit = radius * 0.72;
    for (int i = 0; i < dotCount; i++) {
      final angle = (2 * 3.14159265 / dotCount) * i;
      final dx = center.dx + dotOrbit * _cos(angle);
      final dy = center.dy + dotOrbit * _sin(angle);
      canvas.drawCircle(Offset(dx, dy), dotRadius, dotPaint);
    }

    final innerRing = Paint()
      ..color = ringColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.02;
    canvas.drawCircle(center, radius * 0.58, innerRing);
  }

  double _cos(double a) => a.isFinite ? Offset.fromDirection(a).dx : 0;
  double _sin(double a) => a.isFinite ? Offset.fromDirection(a).dy : 0;

  @override
  bool shouldRepaint(covariant _StampPainter oldDelegate) => false;
}
