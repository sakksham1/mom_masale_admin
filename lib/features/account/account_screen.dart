import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client_provider.dart';
import '../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/route_permissions.dart';
import '../../core/constants/layout_constants.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          LayoutConstants.navBarClearance,
        ),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.maroon,
              child: Text(
                (user?.name.isNotEmpty ?? false)
                    ? user!.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 28,
                  color: AppColors.parchment,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              user?.name ?? 'Unknown',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Center(
            child: Text(
              user?.role.name.toUpperCase() ?? '',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                letterSpacing: 2,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    icon: Icons.mail_outline,
                    label: 'Email',
                    value: user?.email ?? '—',
                  ),
                  const Divider(height: 24),
                  _InfoRow(
                    icon: Icons.call_outlined,
                    label: 'Phone',
                    value: user?.phone ?? 'Not set',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (user != null) ...[
            Text('Quick Links', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: routePermissions.entries
                  .where((e) => e.key != '/me' && e.value.contains(user.role))
                  .map(
                    (e) => ActionChip(
                      label: Text(_routeLabel(e.key)),
                      onPressed: () => context.push(e.key),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.errorContainer,
              foregroundColor: scheme.onErrorContainer,
            ),
            onPressed: () => ref.read(authControllerProvider).logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ],
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
    case '/packaging':
      return 'Report Packaging';
    case '/packaging/history':
      return 'Packaging History';
    case '/sales':
      return 'Sales';
    case '/approvals':
      return 'Approvals';
    case '/db-explorer':
      return 'DB Explorer';
    default:
      return path;
  }
}
