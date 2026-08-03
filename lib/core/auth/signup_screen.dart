import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        phone.isEmpty ||
        _passwordCtrl.text.isEmpty) {
      setState(
        () => _error = 'Name, email, phone, and password are all required.',
      );
      return;
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      setState(() => _error = 'Enter a valid 10-digit phone number.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider)
          .signup(
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            phone: phone,
          );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.charcoal : AppColors.parchment;
    final onCardColor = isDark ? AppColors.parchment : AppColors.cumin;
    final fieldFillColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : AppColors.cumin.withValues(alpha: 0.04);

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
                    Text(
                      'Join the Team',
                      style: textTheme.displayMedium?.copyWith(
                        color: AppColors.parchment,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create your staff account',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.parchment.withValues(alpha: 0.7),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      decoration: BoxDecoration(
                        color: cardColor,
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
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 18),
                            decoration: BoxDecoration(
                              color: AppColors.turmeric.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: AppColors.turmeric,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "After you sign up, an admin needs to assign you a "
                                    "role before you can get in.",
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: onCardColor.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextField(
                            controller: _nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            style: TextStyle(color: onCardColor),
                            decoration: InputDecoration(
                              labelText: 'Full name',
                              filled: true,
                              fillColor: fieldFillColor,
                              labelStyle: TextStyle(
                                color: onCardColor.withValues(alpha: 0.6),
                              ),
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: onCardColor.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: onCardColor),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              filled: true,
                              fillColor: fieldFillColor,
                              labelStyle: TextStyle(
                                color: onCardColor.withValues(alpha: 0.6),
                              ),
                              prefixIcon: Icon(
                                Icons.mail_outline,
                                color: onCardColor.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(color: onCardColor),
                            decoration: InputDecoration(
                              labelText: 'Phone number',
                              filled: true,
                              fillColor: fieldFillColor,
                              labelStyle: TextStyle(
                                color: onCardColor.withValues(alpha: 0.6),
                              ),
                              prefixIcon: Icon(
                                Icons.call_outlined,
                                color: onCardColor.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordCtrl,
                            obscureText: _obscure,
                            style: TextStyle(color: onCardColor),
                            onSubmitted: (_) => _loading ? null : _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              filled: true,
                              fillColor: fieldFillColor,
                              labelStyle: TextStyle(
                                color: onCardColor.withValues(alpha: 0.6),
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: onCardColor.withValues(alpha: 0.6),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: onCardColor.withValues(alpha: 0.6),
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.paprika.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.paprika.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: AppColors.paprika,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: AppColors.paprika,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.maroon,
                              foregroundColor: AppColors.parchment,
                            ),
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.parchment,
                                    ),
                                  )
                                : const Text('Create Account'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(
                        'Already have an account? Sign in',
                        style: TextStyle(
                          color: AppColors.parchment.withValues(alpha: 0.85),
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
