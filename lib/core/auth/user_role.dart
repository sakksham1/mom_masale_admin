enum UserRole {
  admin,
  manager,
  warehouser,
  packaging,
  salesperson,
  customer,
  unknown;

  static UserRole fromString(String? value) {
    switch (value) {
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'warehouser':
        return UserRole.warehouser;
      case 'packaging':
        return UserRole.packaging;
      case 'salesperson':
        return UserRole.salesperson;
      case 'customer':
        return UserRole.customer;
      default:
        return UserRole.unknown;
    }
  }
}
