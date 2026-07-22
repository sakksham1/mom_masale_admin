// lib/core/notifications/push_notification_service.dart
import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../firebase_options.dart';
import '../network/api_client.dart';

/// Must be a top-level (or static) function — the OS calls this in its own
/// isolate when a push arrives while the app is backgrounded/terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Nothing else needed here — a notification+data payload is shown by the
  // OS automatically in this state. This handler exists for data-only
  // processing if you ever need it later.
}

/// Requests permission, registers the device's FCM token with the backend,
/// and shows a local notification when a push arrives while the app is
/// in the foreground (FCM doesn't auto-display foreground notifications).
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();
  ApiClient? _client;
  String? _lastToken;
  bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'mm_admin_default',
    'Mom Masale Admin Alerts',
    description: 'Order, approval, and stock alerts',
    importance: Importance.high,
  );

  Future<void> init(ApiClient client) async {
    _client = client;
    if (_initialized) {
      // Already set up (e.g. re-login as a different staff account) —
      // just re-register the current token against the new user.
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);
      return;
    }
    _initialized = true;

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    await _fln.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _fln
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_channel);
    }

    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    final NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('Push permission status: ${settings.authorizationStatus}');
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    messaging.onTokenRefresh.listen(_registerToken);

    final String? token = await messaging.getToken();
    if (token != null) await _registerToken(token);
  }

  Future<void> _registerToken(String token) async {
    if (_client == null) return;
    _lastToken = token;
    try {
      await _client!.post('/api/notifications/register-token', {
        'token': token,
        'platform': _platformName(),
      });
    } catch (e) {
      debugPrint('Failed to register push token: $e');
    }
  }

  /// Call on logout so a shared/kiosk device stops receiving another
  /// user's pushes once they've signed out.
  Future<void> unregister() async {
    if (_client == null || _lastToken == null) return;
    try {
      await _client!.deleteWithBody('/api/notifications/register-token', {
        'token': _lastToken,
      });
    } catch (e) {
      debugPrint('Failed to unregister push token: $e');
    }
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }

  void _showForegroundNotification(RemoteMessage message) {
    final RemoteNotification? notification = message.notification;
    if (notification == null) return;
    _fln.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
