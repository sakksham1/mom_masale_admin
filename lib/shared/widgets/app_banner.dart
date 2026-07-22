// lib/shared/widgets/app_banner.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Persistent maroon banner shown across every authenticated screen.
/// Lives in HomeShell, so — like the floating nav bar — it's automatically
/// absent from the login screen and any full-screen route pushed via the
/// root navigator (packaging submit/bulk, product edit).
///
/// Built on a real [AppBar] (instead of a bare Container) so it picks up
/// the platform's top safe-area inset automatically. That's what keeps the
/// "Mom Masale" wordmark from sliding in behind status-bar punch-hole /
/// notch cutouts on phones where the front camera lives up top.
class AppBanner extends StatelessWidget implements PreferredSizeWidget {
  const AppBanner({super.key});

  static const double _contentHeight = 40;

  @override
  Size get preferredSize => const Size.fromHeight(_contentHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: _contentHeight,
      backgroundColor: AppColors.maroon,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      title: const Text(
        'Mom Masale',
        style: TextStyle(
          fontFamily: 'Fraunces',
          fontWeight: FontWeight.w600,
          fontSize: 18,
          letterSpacing: 0.5,
          color: AppColors.parchment,
        ),
      ),
    );
  }
}
