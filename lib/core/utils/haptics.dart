import 'package:flutter/services.dart';

/// Thin wrapper so call sites read semantically ("Haptics.success()")
/// instead of picking a raw HapticFeedback method each time.
class Haptics {
  Haptics._();
  static void tap() => HapticFeedback.selectionClick();
  static void success() => HapticFeedback.lightImpact();
  static void warning() => HapticFeedback.mediumImpact();
}
