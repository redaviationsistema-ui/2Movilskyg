import 'package:flutter/material.dart';

import '../core/api_client.dart';

enum AppUserRole { client, operator, admin, unknown }

class AuthProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  BackendUser? _user;
  Map<String, dynamic>? _accessData;
  Map<String, dynamic>? _loginContext;
  Map<String, dynamic>? _userPayload;

  bool isLoading = false;
  String? errorMessage;
  AppUserRole role = AppUserRole.unknown;

  String? get session => _api.hasToken ? 'backend-token' : null;
  BackendUser? get user => _user;
  Map<String, dynamic>? get accessData => _accessData;
  Map<String, dynamic>? get loginContext => _loginContext;
  Map<String, dynamic>? get userPayload => _userPayload;
  bool get isAuthenticated => _user != null;

  String get displayName {
    if (_user?.companyName.isNotEmpty == true) {
      return _user!.companyName;
    }
    if (_user?.name.isNotEmpty == true) {
      return _user!.name;
    }
    return 'Red Sky';
  }

  Future<void> signIn({required String email, required String password}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final normalizedEmail = email.trim().toLowerCase();
      final response = await _api.login(
        email: normalizedEmail,
        password: password,
      );

      _api.setToken(response['token']?.toString());
      _storeSessionPayload(response);
    } on ApiException catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'No fue posible iniciar sesion.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (_user != null && _api.hasToken) {
      try {
        await _api.logout();
      } catch (_) {
        // Limpiamos sesion local aunque el backend no responda.
      }
    }

    _api.setToken(null);
    _user = null;
    _accessData = null;
    _loginContext = null;
    _userPayload = null;
    role = AppUserRole.unknown;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> loadUserRole() async {
    if (!_api.hasToken) {
      role = AppUserRole.unknown;
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.me();
      _storeSessionPayload(response);
    } catch (_) {
      role = AppUserRole.client;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  static AppUserRole roleFromEmail(String? email) {
    final normalized = email?.toLowerCase().trim() ?? '';
    if (normalized.isEmpty) return AppUserRole.unknown;

    if (normalized.contains('admin')) return AppUserRole.admin;
    if (normalized.contains('ops') ||
        normalized.contains('operator') ||
        normalized.contains('operador') ||
        normalized.contains('provider') ||
        normalized.contains('proveedor')) {
      return AppUserRole.operator;
    }

    return AppUserRole.client;
  }

  void _storeSessionPayload(Map<String, dynamic> response) {
    final userJson = Map<String, dynamic>.from(response['user'] as Map);
    _userPayload = userJson;
    _accessData = _asMap(response['access']);
    _loginContext = _asMap(response['login_context']);
    _user = BackendUser.fromJson(userJson);

    role = _roleFromDynamic(_loginContext?['effective_role'] ?? _user!.role);
    if (role == AppUserRole.unknown) {
      role = roleFromEmail(_user!.email);
    }
  }

  AppUserRole _roleFromDynamic(dynamic raw) {
    final value = raw?.toString().toLowerCase().trim();

    switch (value) {
      case 'admin':
      case 'administrator':
        return AppUserRole.admin;
      case 'operator':
      case 'operador':
      case 'provider':
      case 'proveedor':
        return AppUserRole.operator;
      case 'client':
      case 'cliente':
      case 'customer':
      case 'user':
        return AppUserRole.client;
      default:
        return AppUserRole.unknown;
    }
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }
}
