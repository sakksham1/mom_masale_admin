// lib/shared/widgets/swipe_confirm_sheet.dart
import 'package:flutter/material.dart';
import 'swipe_to_confirm.dart';

/// Shared bottom-sheet shell for confirming high-stakes actions (catalog
/// saves, publishing, order changes, approvals) via a deliberate swipe
/// gesture instead of a single tap. Use this instead of a one-off private
/// sheet class — that's how confirmation coverage drifted out of sync
/// across the app in the first place.
class SwipeConfirmSheet {
  SwipeConfirmSheet._();

  static Future<bool> show(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required Widget message,
    String swipeLabel = 'Slide to confirm',
    String cancelLabel = 'Cancel',
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: color),
                        const SizedBox(width: 10),
                        Expanded(child: message),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SwipeToConfirm(
                    label: swipeLabel,
                    color: color,
                    onConfirmed: () => Navigator.pop(sheetContext, true),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: Text(cancelLabel),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return result == true;
  }
}
