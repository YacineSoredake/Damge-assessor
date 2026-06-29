/// Centralized environment config.
/// Swap these values per build flavor (dev/staging/prod) once flavors are set up.
class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.8:4000', 
  );

  static const bool isProd = bool.fromEnvironment('PROD', defaultValue: false);
}
