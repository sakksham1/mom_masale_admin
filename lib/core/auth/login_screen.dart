import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import 'user_role.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authControllerProvider);
      await auth.login(_emailCtrl.text.trim(), _passwordCtrl.text);

      const staffRoles = {
        UserRole.admin,
        UserRole.manager,
        UserRole.warehouser,
        UserRole.packaging,
        UserRole.salesperson,
      };

      if (!staffRoles.contains(auth.role)) {
        _error = 'This account does not have staff access.';
        await auth.logout();
      }
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final denied =
        GoRouterState.of(context).uri.queryParameters['denied'] == '1';
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
                    Image.asset(
                      'assets/images/brand_logo_full.png',
                      height: 150,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Mom Masale',
                      style: textTheme.displayMedium?.copyWith(
                        color: AppColors.parchment,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Admin',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.parchment.withValues(alpha: 0.7),
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 36),
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
                          Text(
                            'Welcome back',
                            style: textTheme.titleLarge?.copyWith(
                              color: onCardColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sign in to manage orders and customers.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: onCardColor.withValues(alpha: 0.65),
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (denied) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppColors.paprika.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.paprika.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: const Text(
                                "Your account doesn't have access to that page. "
                                'Please sign in with an account that has the right role.',
                                style: TextStyle(
                                  color: AppColors.paprika,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
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
                            controller: _passwordCtrl,
                            obscureText: _obscure,
                            style: TextStyle(color: onCardColor),
                            onSubmitted: (_) => _loading ? null : _login(),
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
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.parchment,
                                    ),
                                  )
                                : const Text('Sign in'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'For staff use only',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.parchment.withValues(alpha: 0.4),
                        fontSize: 12,
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
