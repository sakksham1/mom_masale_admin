import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/auth/user_role.dart';

/// Circular icon badge — the single visual language for "state at a glance"
/// across the app. Same shape/size everywhere (soft tinted fill + outline
/// ring + centered icon) so an order's payment state and a customer's role
/// read as one consistent system, not two different patterns.
class StatusBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const StatusBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// Order status badge — driven primarily by payment_status, with a
/// cancelled fulfilment status overriding everything else since it's the
/// more urgent signal for whoever's scanning the list.
///
///   paid      → green check
///   cod       → amber check   (confirmed order, payment on delivery)
///   failed    → red cross
///   created   → charcoal "?"  (order placed, payment not yet resolved)
///   cancelled → red "!"       (overrides payment state)
class OrderStatusBadge extends StatelessWidget {
  final String status; // placed | packed | shipped | delivered | cancelled
  final String paymentStatus; // created | paid | failed | cod

  const OrderStatusBadge({
    super.key,
    required this.status,
    required this.paymentStatus,
  });

  ({IconData icon, Color color}) _visual() {
    if (status == 'cancelled') {
      return (icon: Icons.priority_high, color: const Color(0xFFC62828));
    }
    switch (paymentStatus) {
      case 'paid':
        return (icon: Icons.check, color: const Color(0xFF2E7D32));
      case 'cod':
        return (icon: Icons.check, color: const Color(0xFFC98A1F));
      case 'failed':
        return (icon: Icons.close, color: const Color(0xFFC62828));
      case 'created':
        return (icon: Icons.question_mark, color: const Color(0xFF33261F));
      default:
        // Future/unknown payment_status values fall back gracefully.
        return (icon: Icons.help_outline, color: const Color(0xFF33261F));
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _visual();
    return StatusBadge(icon: v.icon, color: v.color);
  }
}

/// Customer role badge — replaces the generic "first letter" avatar with a
/// role-coded icon, pulling from the existing brand palette so it feels
/// native to the rest of the app rather than a bolted-on new color scheme.
class RoleAvatar extends StatelessWidget {
  final UserRole role;
  const RoleAvatar({super.key, required this.role});

  ({IconData icon, Color color}) _visual() {
    switch (role) {
      case UserRole.admin:
        return (icon: Icons.shield, color: AppColors.maroon);
      case UserRole.manager:
        return (icon: Icons.supervisor_account, color: AppColors.paprika);
      case UserRole.warehouser:
        return (icon: Icons.warehouse, color: AppColors.cumin);
      case UserRole.packaging:
        return (icon: Icons.inventory_2, color: const Color(0xFF5A6B7A));
      case UserRole.salesperson:
        return (icon: Icons.point_of_sale, color: AppColors.turmeric);
      case UserRole.customer:
        return (icon: Icons.person, color: const Color(0xFF8A97A3));
      case UserRole.unknown:
        return (icon: Icons.help_outline, color: Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _visual();
    return StatusBadge(icon: v.icon, color: v.color);
  }
}
