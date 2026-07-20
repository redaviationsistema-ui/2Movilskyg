import 'package:flutter/foundation.dart';

enum AppEnvironmentName { development, staging, production }

class AppEnvironment {
  const AppEnvironment._({required this.name, required this.apiBaseUrl});

  static final AppEnvironment current = _fromDefines();

  final AppEnvironmentName name;
  final String apiBaseUrl;

  bool get isProduction => name == AppEnvironmentName.production;
  bool get showsEnvironmentBadge => !isProduction;
  bool get allowsDiagnosticLogs => name == AppEnvironmentName.development;
  String get label => name.name.toUpperCase();

  static AppEnvironment _fromDefines() {
    const rawName = String.fromEnvironment(
      'APP_ENV',
      defaultValue: kReleaseMode ? 'production' : 'development',
    );
    const rawUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://uber-aviones.onrender.com/api/v1',
    );
    final name = AppEnvironmentName.values.firstWhere(
      (item) => item.name == rawName.trim().toLowerCase(),
      orElse:
          () =>
              throw StateError(
                'APP_ENV debe ser development, staging o production.',
              ),
    );
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('API_BASE_URL no es una URL válida.');
    }
    if (name != AppEnvironmentName.development && uri.scheme != 'https') {
      throw StateError('API_BASE_URL debe usar HTTPS fuera de development.');
    }
    return AppEnvironment._(
      name: name,
      apiBaseUrl: rawUrl.trim().replaceAll(RegExp(r'/+$'), ''),
    );
  }
}
