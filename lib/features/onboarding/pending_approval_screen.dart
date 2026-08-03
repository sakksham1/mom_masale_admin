import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/brand_logo.dart';

/// Landing spot for a freshly-signed-up app account (role still 'customer').
/// Stays logged in — the person just waits here until an admin assigns a
/// role via the Business > Customers screen, then taps "Check Again".
class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});
  @override
  ConsumerState<PendingApprovalScreen> createState() =>
      _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends ConsumerState<PendingApprovalScreen> {
  bool _checking = false;

  Future<void> _checkAgain() async {
    setState(() => _checking = true);
    await ref.read(authControllerProvider).restoreSession();
    // If the role changed, AuthController.notifyListeners() (called inside
    // restoreSession) triggers the router's refreshListenable and the
    // redirect logic sends them on to their real landing screen automatically.
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final name = auth.user?.name ?? '';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.maroon, AppColors.charcoal],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLogo(size: 88),
                  const SizedBox(height: 28),
                  const Icon(
                    Icons.hourglass_top_rounded,
                    color: AppColors.turmeric,
                    size: 40,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    name.isEmpty ? "You're almost in" : "Almost there, $name",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.parchment,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your account is created. An admin needs to assign you a '
                    "role before you can get in — they've been notified.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.parchment.withValues(alpha: 0.75),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.turmeric,
                      foregroundColor: AppColors.charcoal,
                      minimumSize: const Size(220, 50),
                    ),
                    onPressed: _checking ? null : _checkAgain,
                    icon: _checking
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(_checking ? 'Checking…' : 'Check Again'),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => ref.read(authControllerProvider).logout(),
                    child: Text(
                      'Log out',
                      style: TextStyle(
                        color: AppColors.parchment.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
