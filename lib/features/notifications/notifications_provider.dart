import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notifications_api.dart';
import '../../core/network/api_client_provider.dart' show apiClientProvider;

final notificationsApiProvider = Provider(
  (ref) => NotificationsApi(ref.watch(apiClientProvider)),
);

/// Polls /api/admin/notifications every 20s while something is listening
/// (i.e. while the bell widget is on screen), and stops automatically via
/// autoDispose when nothing is watching it anymore.
final notificationsPollProvider =
    StreamProvider.autoDispose<NotificationsFetchResult>((ref) {
      final api = ref.watch(notificationsApiProvider);
      late final StreamController<NotificationsFetchResult> controller;
      Timer? timer;

      Future<void> tick() async {
        try {
          controller.add(await api.fetch());
        } catch (_) {
          // Stay quiet on transient network errors — the bell just won't
          // update this cycle and will retry on the next tick.
        }
      }

      controller = StreamController<NotificationsFetchResult>(
        onListen: () {
          tick();
          timer = Timer.periodic(const Duration(seconds: 20), (_) => tick());
        },
        onCancel: () => timer?.cancel(),
      );

      ref.onDispose(() {
        timer?.cancel();
        controller.close();
      });

      return controller.stream;
    });
