import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/brand_logo.dart';

/// Gate between signup and everything else. A signup OTP was already sent
/// by the backend as part of /api/auth/signup — this screen collects it
/// (with a resend option) and calls /api/auth/verify-email.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});
  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _otpCtrl = TextEditingController();
  bool _submitting = false;
  bool _resending = false;
  String? _error;
  String? _info;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _otpCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendCooldown = (_resendCooldown - 1).clamp(0, 60));
      if (_resendCooldown == 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      final sent = await ref.read(authControllerProvider).sendVerifyOtp();
      setState(() {
        _info = sent
            ? 'A new code has been sent to your email.'
            : 'Please wait a bit before requesting another code.';
      });
      _startCooldown();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _verify() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authControllerProvider).verifyEmail(otp);
      // Router redirect picks up emailVerified=true automatically.
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final email = auth.user?.email ?? '';

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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandLogo(size: 80),
                    const SizedBox(height: 24),
                    Text(
                      'Verify Your Email',
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(color: AppColors.parchment),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email.isEmpty
                          ? "We've sent a 6-digit code to your email."
                          : "We've sent a 6-digit code to $email.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.parchment.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      decoration: BoxDecoration(
                        color: AppColors.parchment,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _otpCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              letterSpacing: 8,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cumin,
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              labelText: 'Verification code',
                            ),
                            onSubmitted: (_) => _submitting ? null : _verify(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.paprika,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          if (_info != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _info!,
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.maroon,
                              foregroundColor: AppColors.parchment,
                            ),
                            onPressed: _submitting ? null : _verify,
                            child: _submitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.parchment,
                                    ),
                                  )
                                : const Text('Verify'),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: (_resending || _resendCooldown > 0)
                                ? null
                                : _resend,
                            child: Text(
                              _resendCooldown > 0
                                  ? 'Resend code in ${_resendCooldown}s'
                                  : (_resending
                                        ? 'Sending…'
                                        : "Didn't get it? Resend"),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () =>
                          ref.read(authControllerProvider).logout(),
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
      ),
    );
  }
}
