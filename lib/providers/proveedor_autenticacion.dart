import 'dart:io';

import 'package:flutter/material.dart';

import '../core/cliente_api.dart';

enum AppUserRole { client, operator, admin, crew, unknown }

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

  Future<bool> registerClient({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    String birthDate = '',
    String nationality = '',
    String base = '',
    String documentType = 'INE',
    String documentNumber = '',
    String documentIssueDate = '',
    String documentExpiration = '',
    String documentStatus = '',
    String ineCurp = '',
    String ineCic = '',
    String ineOcr = '',
    String ineScanRaw = '',
    String ineScanStatus = '',
    String identityVerificationStatus = '',
    String identityVerificationMessage = '',
    bool identityVerified = false,
    bool faceDetected = false,
    int facesCount = 0,
    double? faceConfidence,
    double? qualityBrightness,
    double? qualitySharpness,
    double? poseYaw,
    double? posePitch,
    double? poseRoll,
    bool? faceOccluded,
    bool biometricImageSaved = false,
    String biometricCapturedAt = '',
    String biometricProvider = 'aws_rekognition',
    String biometricTemplateType = 'selfie-photo',
    File? ineFront,
    File? ineBack,
    File? selfieBiometric,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.registerClient(
        name: name.trim(),
        email: email.trim().toLowerCase(),
        phone: phone.trim(),
        password: password,
        passwordConfirmation: passwordConfirmation,
        birthDate: birthDate,
        nationality: nationality.trim(),
        base: base.trim(),
        documentType: documentType.trim().isEmpty ? 'INE' : documentType.trim(),
        documentNumber: documentNumber.trim(),
        documentIssueDate: documentIssueDate.trim(),
        documentExpiration: documentExpiration.trim(),
        documentStatus: documentStatus.trim(),
        ineCurp: ineCurp.trim(),
        ineCic: ineCic.trim(),
        ineOcr: ineOcr.trim(),
        ineScanRaw: ineScanRaw.trim(),
        ineScanStatus: ineScanStatus.trim(),
        identityVerificationStatus: identityVerificationStatus.trim(),
        identityVerificationMessage: identityVerificationMessage.trim(),
        identityVerified: identityVerified,
        faceDetected: faceDetected,
        facesCount: facesCount,
        faceConfidence: faceConfidence,
        qualityBrightness: qualityBrightness,
        qualitySharpness: qualitySharpness,
        poseYaw: poseYaw,
        posePitch: posePitch,
        poseRoll: poseRoll,
        faceOccluded: faceOccluded,
        biometricImageSaved: biometricImageSaved,
        biometricCapturedAt: biometricCapturedAt,
        biometricProvider: biometricProvider,
        biometricTemplateType: biometricTemplateType,
        ineFront: ineFront,
        ineBack: ineBack,
        selfieBiometric: selfieBiometric,
      );

      final token = _resolveToken(response);
      if (token != null) _api.setToken(token);
      _storeSessionPayload(response);
      return true;
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error);
      return false;
    } catch (_) {
      errorMessage = 'No fue posible crear la cuenta.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerCrew({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    String base = '',
    String birthDate = '',
    String nationality = '',
    String licenseNumber = '',
    String licenseType = 'Licencia de sobrecargo',
    String licenseCategory = '',
    String licenseIssueDate = '',
    String licenseExpiration = '',
    String licenseStatus = '',
    String issuingCountry = '',
    String scanRaw = '',
    String scanStatus = '',
    File? documentFront,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.registerCrew(
        name: name.trim(),
        email: email.trim().toLowerCase(),
        phone: phone.trim(),
        password: password,
        passwordConfirmation: passwordConfirmation,
        base: base.trim(),
        birthDate: birthDate.trim(),
        nationality: nationality.trim(),
        licenseNumber: licenseNumber.trim(),
        licenseType: licenseType.trim(),
        licenseCategory: licenseCategory.trim(),
        documentIssueDate: licenseIssueDate.trim(),
        licenseExpiration: licenseExpiration.trim(),
        documentStatus: licenseStatus.trim(),
        issuingCountry: issuingCountry.trim(),
        ineScanRaw: scanRaw.trim(),
        ineScanStatus: scanStatus.trim(),
        documentFront: documentFront,
      );

      final token = _resolveToken(response);
      if (token != null) _api.setToken(token);
      _storeSessionPayload(response);
      return true;
    } on ApiException catch (error) {
      errorMessage = _apiErrorMessage(error);
      return false;
    } catch (_) {
      errorMessage = 'No fue posible crear la cuenta de sobrecargo.';
      return false;
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
    if (normalized.contains('crew') ||
        normalized.contains('sobrecargo') ||
        normalized.contains('tripulacion') ||
        normalized.contains('flightattendant')) {
      return AppUserRole.crew;
    }
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
    final data = _asMap(response['data']) ?? const {};
    final rawUser = response['user'] ?? data['user'] ?? data['account'];
    if (rawUser is! Map) {
      throw const ApiException('La respuesta no incluyo datos de usuario.');
    }

    final token = _resolveToken(response);
    if (token != null) _api.setToken(token);
    final userJson = Map<String, dynamic>.from(rawUser);
    _userPayload = userJson;
    _accessData = _asMap(response['access'] ?? data['access']);
    _loginContext = _asMap(
      response['login_context'] ??
          data['login_context'] ??
          data['loginContext'],
    );
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
      case 'crew':
      case 'sobrecargo':
      case 'flight_attendant':
      case 'flight-attendant':
      case 'tripulacion':
      case 'cabin_crew':
      case 'cabin-crew':
        return AppUserRole.crew;
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

  String? _resolveToken(Map<String, dynamic> response) {
    final data = _asMap(response['data']) ?? const {};
    return response['token']?.toString() ??
        response['access_token']?.toString() ??
        response['plainTextToken']?.toString() ??
        data['token']?.toString() ??
        data['access_token']?.toString() ??
        data['plainTextToken']?.toString();
  }

  String _apiErrorMessage(ApiException error) {
    final rawErrors = error.payload?['errors'];
    if (rawErrors is! Map) return error.message;

    final details = <String>[];
    for (final entry in rawErrors.entries) {
      final messages = entry.value;
      if (messages is List) {
        details.addAll(messages.where((item) => item != null).map((item) {
          final field = entry.key == 'email' ? 'Correo' : entry.key;
          return '$field: $item';
        }));
      }
    }

    return details.isEmpty ? error.message : '${error.message}\n${details.join('\n')}';
  }
}
