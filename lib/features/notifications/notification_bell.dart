import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notifications_api.dart';
import 'notifications_provider.dart';

/// Bell icon with an unread-count badge, drop into any AppBar.actions.
/// Tapping opens a dropdown of recent notifications; tapping an item marks
/// it read; "Mark all as read" clears the badge.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pollAsync = ref.watch(notificationsPollProvider);
    final unread = pollAsync.maybeWhen(
      data: (d) => d.unreadCount,
      orElse: () => 0,
    );
    final notifications = pollAsync.maybeWhen(
      data: (d) => d.notifications,
      orElse: () => <AppNotification>[],
    );

    return PopupMenuButton<void>(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (unread > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFC62828),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      itemBuilder: (context) {
        if (notifications.isEmpty) {
          return [
            const PopupMenuItem<void>(
              enabled: false,
              child: Text('No notifications yet'),
            ),
          ];
        }
        return [
          for (final n in notifications.take(10))
            PopupMenuItem<void>(
              onTap: () => ref
                  .read(notificationsApiProvider)
                  .markRead(id: n.id)
                  .then((_) => ref.invalidate(notificationsPollProvider)),
              child: SizedBox(
                width: 280,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5, right: 8),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: n.isUnread
                            ? const Color(0xFF2E7D32)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: n.isUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          if (n.body != null)
                            Text(n.body!, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (unread > 0)
            PopupMenuItem<void>(
              onTap: () => ref
                  .read(notificationsApiProvider)
                  .markRead()
                  .then((_) => ref.invalidate(notificationsPollProvider)),
              child: const Text(
                'Mark all as read',
                style: TextStyle(fontSize: 13),
              ),
            ),
        ];
      },
    );
  }
}
