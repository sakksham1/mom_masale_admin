/// Shared rupee formatter used across the admin screens (dashboard,
/// orders, customers) so the comma-grouping logic lives in one place.
String formatRupees(int amount) {
  final digits = amount.toString();
  final withCommas = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  return '₹$withCommas';
}
