import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Shared with PushNotificationService's identical private method — kept
/// here so login/signup calls and FCM registration report the same string.
String platformName() {
  if (kIsWeb) return 'web';
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  return 'other';
}
