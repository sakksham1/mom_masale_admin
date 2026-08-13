import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/success_pulse.dart';

/// Two-step email change: enter the new address (OTP sent there), then
/// confirm the code. Nothing on the account changes until the OTP is
/// verified — see request-email-change.js / confirm-email-change.js.
class ChangeEmailScreen extends ConsumerStatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  ConsumerState<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends ConsumerState<ChangeEmailScreen> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  int _step = 0; // 0 = enter email, 1 = enter otp
  bool _submitting = false;
  String? _error;
  String? _pendingEmail;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _emailCtrl.dispose();
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

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider).requestEmailChange(email);
      _pendingEmail = email;
      _startCooldown();
      Haptics.tap();
      setState(() => _step = 1);
    } on ApiException catch (e) {
      Haptics.warning();
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirm() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit code sent to your new email');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider).confirmEmailChange(otp);
      Haptics.success();
      if (mounted) await SuccessPulse.show(context, 'Email updated');
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      Haptics.warning();
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.parchment,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.turmeric.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _step == 0
                                  ? Icons.alternate_email
                                  : Icons.mark_email_read_outlined,
                              color: AppColors.turmeric,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _step == 0
                                ? 'Change Your Email'
                                : 'Verify New Email',
                            style: Theme.of(context).textTheme.displayMedium
                                ?.copyWith(
                                  color: AppColors.parchment,
                                  fontSize: 26,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _step == 0
                                ? "Enter the new email you'd like to use. We'll send a code there to confirm it's yours."
                                : "We've sent a 6-digit code to $_pendingEmail.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.parchment.withValues(
                                alpha: 0.75,
                              ),
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
                                if (_step == 0) ...[
                                  TextField(
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    autofocus: true,
                                    style: const TextStyle(
                                      color: AppColors.cumin,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'New email',
                                      prefixIcon: Icon(Icons.mail_outline),
                                    ),
                                    onSubmitted: (_) =>
                                        _submitting ? null : _sendCode(),
                                  ),
                                ] else ...[
                                  TextField(
                                    controller: _otpCtrl,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    textAlign: TextAlign.center,
                                    autofocus: true,
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
                                    onSubmitted: (_) =>
                                        _submitting ? null : _confirm(),
                                  ),
                                ],
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
                                const SizedBox(height: 18),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.maroon,
                                    foregroundColor: AppColors.parchment,
                                  ),
                                  onPressed: _submitting
                                      ? null
                                      : (_step == 0 ? _sendCode : _confirm),
                                  child: _submitting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.parchment,
                                          ),
                                        )
                                      : Text(
                                          _step == 0 ? 'Send Code' : 'Confirm',
                                        ),
                                ),
                                if (_step == 1) ...[
                                  const SizedBox(height: 10),
                                  TextButton(
                                    onPressed:
                                        (_submitting || _resendCooldown > 0)
                                        ? null
                                        : _sendCode,
                                    child: Text(
                                      _resendCooldown > 0
                                          ? 'Resend code in ${_resendCooldown}s'
                                          : "Didn't get it? Resend",
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _submitting
                                        ? null
                                        : () => setState(() {
                                            _step = 0;
                                            _otpCtrl.clear();
                                            _error = null;
                                          }),
                                    child: const Text('Use a different email'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
