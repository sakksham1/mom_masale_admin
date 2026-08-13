import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../shared/widgets/success_pulse.dart';

/// Three-step password change, built on the existing forgot-password OTP
/// endpoints (there's no "change password while logged in" endpoint):
///   1. Send a code to the account's current email
///   2. Verify the code -> get a short-lived resetToken
///   3. Set the new password
/// reset-password.js revokes every session for the account on success, so
/// this ends by logging the user out locally and letting the router send
/// them back to /login.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _otpCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  int _step = 0; // 0 = send code, 1 = verify code, 2 = set new password
  bool _submitting = false;
  bool _obscureNew = true, _obscureConfirm = true;
  String? _error;
  String? _resetToken;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  String get _email => ref.read(authControllerProvider).user?.email ?? '';

  @override
  void dispose() {
    _otpCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
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
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).sendPasswordResetOtp(_email);
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

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit code sent to your email');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      _resetToken = await ref
          .read(apiClientProvider)
          .verifyPasswordResetOtp(_email, otp);
      Haptics.tap();
      setState(() => _step = 2);
    } on ApiException catch (e) {
      Haptics.warning();
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _setNewPassword() async {
    final pw = _newPasswordCtrl.text;
    final confirm = _confirmPasswordCtrl.text;
    if (pw != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (_resetToken == null) {
      setState(() => _error = 'Please verify the code again');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .resetPassword(
            email: _email,
            resetToken: _resetToken!,
            newPassword: pw,
          );
      Haptics.success();
      if (mounted) {
        await SuccessPulse.show(
          context,
          'Password changed — please sign in again',
        );
      }
      if (mounted) {
        await ref.read(authControllerProvider).logout();
      }
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
                              _step == 2
                                  ? Icons.lock_reset
                                  : Icons.lock_outline,
                              color: AppColors.turmeric,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            switch (_step) {
                              0 => 'Change Your Password',
                              1 => "Verify It's You",
                              _ => 'Set a New Password',
                            },
                            style: Theme.of(context).textTheme.displayMedium
                                ?.copyWith(
                                  color: AppColors.parchment,
                                  fontSize: 26,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            switch (_step) {
                              0 =>
                                "We'll send a verification code to $_email to confirm it's you. Changing your password signs you out everywhere, including this device.",
                              1 => 'Enter the 6-digit code sent to $_email.',
                              _ =>
                                'Choose a strong new password — at least 8 characters with a mix of upper/lowercase, a number, and a symbol.',
                            },
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
                                if (_step == 1) ...[
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
                                        _submitting ? null : _verifyOtp(),
                                  ),
                                ] else if (_step == 2) ...[
                                  TextField(
                                    controller: _newPasswordCtrl,
                                    obscureText: _obscureNew,
                                    autofocus: true,
                                    style: const TextStyle(
                                      color: AppColors.cumin,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'New password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureNew
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                        onPressed: () => setState(
                                          () => _obscureNew = !_obscureNew,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: _confirmPasswordCtrl,
                                    obscureText: _obscureConfirm,
                                    style: const TextStyle(
                                      color: AppColors.cumin,
                                    ),
                                    onSubmitted: (_) =>
                                        _submitting ? null : _setNewPassword(),
                                    decoration: InputDecoration(
                                      labelText: 'Confirm new password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureConfirm
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                        onPressed: () => setState(
                                          () => _obscureConfirm =
                                              !_obscureConfirm,
                                        ),
                                      ),
                                    ),
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
                                      : switch (_step) {
                                          0 => _sendCode,
                                          1 => _verifyOtp,
                                          _ => _setNewPassword,
                                        },
                                  child: _submitting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.parchment,
                                          ),
                                        )
                                      : Text(switch (_step) {
                                          0 => 'Send Code',
                                          1 => 'Verify',
                                          _ => 'Change Password',
                                        }),
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
