// lib/core/constants/layout_constants.dart
/// Shared layout constants for the floating bottom nav so every scrollable
/// screen leaves enough room at the bottom to avoid being covered by it.
class LayoutConstants {
  LayoutConstants._();

  /// Height of the floating nav bar itself (see HomeShell).
  static const double navBarHeight = 64;

  /// Distance the nav bar floats above the screen edge.
  static const double navBarBottomMargin = 16;

  /// Space to reserve at the end of scrollable content so the last item
  /// isn't hidden behind the floating nav bar, plus a little breathing room.
  static const double navBarClearance =
      navBarHeight + navBarBottomMargin + 24; // 104

  /// Extra bottom padding for a FAB that lives inside a normal Scaffold
  /// (Scaffold already insets FABs ~16px, so this tops it up to clear the
  /// floating nav bar).
  static const double fabScaffoldExtraPadding = 76;
}
