import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sessions_api.dart';
import 'sessions_provider.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/haptics.dart';
import '../../core/theme/app_colors.dart';

IconData _platformIcon(String? platform) {
  switch (platform) {
    case 'android':
      return Icons.android;
    case 'ios':
    case 'macos':
      return Icons.phone_iphone;
    case 'windows':
      return Icons.desktop_windows_outlined;
    case 'linux':
      return Icons.computer;
    case 'web':
      return Icons.language;
    default:
      return Icons.devices_other;
  }
}

String _platformLabel(String? platform) {
  switch (platform) {
    case 'android':
      return 'Android';
    case 'ios':
      return 'iOS';
    case 'macos':
      return 'macOS';
    case 'windows':
      return 'Windows';
    case 'linux':
      return 'Linux';
    case 'web':
      return 'Web browser';
    default:
      return 'Unknown device';
  }
}

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(userSessionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Sessions')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(userSessionsProvider),
        child: sessionsAsync.when(
          data: (sessions) {
            if (sessions.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: Text('No active sessions found.')),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _SessionTile(session: sessions[i]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load sessions: $e')),
        ),
      ),
    );
  }
}

class _SessionTile extends ConsumerStatefulWidget {
  final UserSession session;
  const _SessionTile({required this.session});

  @override
  ConsumerState<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends ConsumerState<_SessionTile> {
  bool _busy = false;

  Future<void> _revoke() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out this device?'),
        content: Text(
          'This will sign out the ${_platformLabel(widget.session.platform)} session '
          'last active on ${widget.session.lastSeenAt}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(sessionsApiProvider).revoke(widget.session.id);
      Haptics.tap();
      ref.invalidate(userSessionsProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: s.isCurrent
              ? AppColors.turmeric.withValues(alpha: 0.5)
              : scheme.outlineVariant.withValues(alpha: 0.4),
          width: s.isCurrent ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(_platformIcon(s.platform), color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _platformLabel(s.platform),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (s.isCurrent) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: const Text(
                          'This device',
                          style: TextStyle(fontSize: 10),
                        ),
                        backgroundColor: AppColors.turmeric.withValues(
                          alpha: 0.18,
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Last active ${s.lastSeenAt}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Signed in ${s.createdAt}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (!s.isCurrent)
            _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: Icon(
                      Icons.logout,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    tooltip: 'Log out this device',
                    onPressed: _revoke,
                  ),
        ],
      ),
    );
  }
}
