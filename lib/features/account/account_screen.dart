import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../core/auth/route_permissions.dart';
import '../../core/auth/user_role.dart';
import '../../core/constants/layout_constants.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/tap_scale.dart';
import '../customers/role_display.dart';
import 'edit_profile_screen.dart';
import 'change_email_screen.dart';
import 'change_password_screen.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final scheme = Theme.of(context).colorScheme;
    final accent = roleColor(auth.role);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: scheme.surface,
            title: const Text('Me'),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              LayoutConstants.navBarClearance,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _HeroCard(
                  name: user?.name ?? 'Unknown',
                  email: user?.email ?? '—',
                  role: auth.role,
                  accent: accent,
                  onEdit: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  icon: Icons.shield_outlined,
                  title: 'Login & Security',
                  accent: accent,
                  children: [
                    _SettingRow(
                      icon: Icons.mail_outline,
                      label: 'Email',
                      value: user?.email ?? '—',
                      trailing: (user?.emailVerified ?? false)
                          ? const _StatusChip(
                              label: 'Verified',
                              color: Color(0xFF2E7D32),
                            )
                          : const _StatusChip(
                              label: 'Unverified',
                              color: AppColors.paprika,
                            ),
                      actionLabel: 'Change',
                      onAction: () =>
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => const ChangeEmailScreen(),
                            ),
                          ),
                    ),
                    const Divider(height: 28),
                    _SettingRow(
                      icon: Icons.lock_outline,
                      label: 'Password',
                      value: '••••••••••',
                      actionLabel: 'Change',
                      onAction: () =>
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => const ChangePasswordScreen(),
                            ),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  accent: accent,
                  children: [
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: Icon(Icons.brightness_auto_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode_outlined),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode_outlined),
                        ),
                      ],
                      selected: {ref.watch(themeModeProvider)},
                      onSelectionChanged: (selection) =>
                          ref.read(themeModeProvider.notifier).state =
                              selection.first,
                    ),
                  ],
                ),
                if (user != null) ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    icon: Icons.apps_outlined,
                    title: 'Quick Links',
                    accent: accent,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: routePermissions.entries
                            .where(
                              (e) =>
                                  e.key != '/me' && e.value.contains(user.role),
                            )
                            .map(
                              (e) => ActionChip(
                                label: Text(_routeLabel(e.key)),
                                onPressed: () => context.push(e.key),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(
                        color: scheme.error.withValues(alpha: 0.4),
                      ),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      final confirmed = await ConfirmDialog.show(
                        context,
                        title: 'Log out?',
                        message: "You'll need to sign in again to continue.",
                        confirmLabel: 'Log out',
                        icon: Icons.logout,
                        destructive: true,
                      );
                      if (confirmed) {
                        await ref.read(authControllerProvider).logout();
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Log out'),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final String name, email;
  final UserRole role;
  final Color accent;
  final VoidCallback onEdit;
  const _HeroCard({
    required this.name,
    required this.email,
    required this.role,
    required this.accent,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.20),
            AppColors.maroon.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent, accent.withValues(alpha: 0.7)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: scheme.surface, width: 3),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: TapScale(
                  onTap: onEdit,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withValues(alpha: 0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(Icons.edit_outlined, size: 16, color: accent),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(roleIcon(role), size: 14, color: accent),
                const SizedBox(width: 6),
                Text(
                  roleLabel(role),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared section shell ────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final List<Widget> children;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.accent,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Widget? trailing;
  final String actionLabel;
  final VoidCallback onAction;
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

String _routeLabel(String path) {
  switch (path) {
    case '/dashboard':
      return 'Dashboard';
    case '/business':
      return 'Business';
    case '/stock':
      return 'Stock';
    case '/site':
      return 'Site';
    case '/catalog':
      return 'Catalog';
    case '/reviews':
      return 'Reviews';
    case '/recipes':
      return 'Recipes';
    case '/blog':
      return 'Blog';
    case '/site-core':
      return 'Site Settings';
    case '/themes':
      return 'Site Themes';
    case '/coupons':
      return 'Coupons';
    case '/wheel':
      return 'Spice Wheel';
    case '/packaging':
      return 'Report Packaging';
    case '/packaging/history':
      return 'Packaging History';
    case '/sales':
      return 'Sales';
    case '/approvals':
      return 'Approvals';
    case '/careers':
      return 'Careers';
    case '/db-explorer':
      return 'DB Explorer';
    case '/sessions':
      return 'My Sessions';
    case '/analytics':
      return 'Analytics';
    case '/publish-queue':
      return 'Publish Queue';
    case '/my-requests':
      return 'My Requests';
    default:
      return path;
  }
}
