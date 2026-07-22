import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'staff_logins_provider.dart';
import '../../core/constants/layout_constants.dart';
import '../../shared/widgets/status_badge.dart';
import '../../core/auth/user_role.dart';

RoleAvatar _avatarFor(String roleStr) =>
    RoleAvatar(role: UserRole.fromString(roleStr));

class StaffLoginsSection extends ConsumerWidget {
  const StaffLoginsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loginsAsync = ref.watch(staffLoginsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(staffLoginsProvider),
      child: loginsAsync.when(
        data: (logins) {
          if (logins.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text('No staff logins recorded yet.')),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              12,
              12,
              12,
              LayoutConstants.navBarClearance,
            ),
            itemCount: logins.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final l = logins[i];
              return ListTile(
                leading: _avatarFor(l.userRole),
                title: Text(l.userName),
                subtitle: Text(
                  '${l.userRole} · ${l.platform ?? 'unknown device'}',
                ),
                trailing: Text(
                  l.createdAt,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Could not load login activity: $e')),
      ),
    );
  }
}
