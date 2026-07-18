/// Centralizes environment-specific config. Override at build/run time:
///   flutter run --dart-define=API_BASE_URL=https://staging.mommasale.com
class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mommasale.com',
  );
}