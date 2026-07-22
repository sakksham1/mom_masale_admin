import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Persistent maroon banner shown across every authenticated screen.
/// Lives in HomeShell, so — like the floating nav bar — it's automatically
/// absent from the login screen and any full-screen route pushed via the
/// root navigator (packaging submit/bulk, product edit).
class AppBanner extends StatelessWidget implements PreferredSizeWidget {
  const AppBanner({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      width: double.infinity,
      color: AppColors.maroon,
      alignment: Alignment.center,
      child: const Text(
        'Mom Masale',
        style: TextStyle(
          fontFamily: 'Fraunces', // heading font, per AppTypography
          fontWeight: FontWeight.w600,
          fontSize: 18,
          letterSpacing: 0.5,
          color: AppColors.parchment,
        ),
      ),
    );
  }
}
