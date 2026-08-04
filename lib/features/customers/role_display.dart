import 'package:flutter/material.dart';
import '../../core/auth/user_role.dart';
import '../../core/theme/app_colors.dart';

String roleLabel(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'Admin';
    case UserRole.manager:
      return 'Manager';
    case UserRole.warehouser:
      return 'Warehouser';
    case UserRole.packaging:
      return 'Packaging';
    case UserRole.salesperson:
      return 'Salesperson';
    case UserRole.customer:
      return 'Customer';
    case UserRole.unknown:
      return 'Unknown';
  }
}

IconData roleIcon(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return Icons.shield;
    case UserRole.manager:
      return Icons.supervisor_account;
    case UserRole.warehouser:
      return Icons.warehouse;
    case UserRole.packaging:
      return Icons.inventory_2;
    case UserRole.salesperson:
      return Icons.point_of_sale;
    case UserRole.customer:
      return Icons.person;
    case UserRole.unknown:
      return Icons.help_outline;
  }
}

Color roleColor(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return AppColors.maroon;
    case UserRole.manager:
      return AppColors.paprika;
    case UserRole.warehouser:
      return AppColors.cumin;
    case UserRole.packaging:
      return const Color(0xFF5A6B7A);
    case UserRole.salesperson:
      return AppColors.turmeric;
    case UserRole.customer:
      return const Color(0xFF8A97A3);
    case UserRole.unknown:
      return Colors.grey;
  }
}

const assignableRoles = [
  UserRole.customer,
  UserRole.salesperson,
  UserRole.packaging,
  UserRole.warehouser,
  UserRole.manager,
  UserRole.admin,
];
