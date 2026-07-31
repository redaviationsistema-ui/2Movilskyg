import 'dart:io';

import 'package:flutter/material.dart';

import '../core/acceso_comercial_cliente.dart';
import '../core/auth/secure_session_storage.dart';
import '../core/auth/session_cleanup_registry.dart';
import '../core/cliente_api.dart';
import '../services/servicio_notificaciones.dart';

enum AppUserRole { client, operator, admin, crew, unknown }

enum SessionBootstrapState {
  checking,
  authenticated,
  signedOut,
  offline,
  denied,
}

class AuthProvider extends ChangeNotifier {
  AuthProvider({ApiClient? api, SessionStorage? sessionStorage})
    : _api = api ?? ApiClient.instance,
      _sessionStorage = sessionStorage ?? SecureSessionStorage() {
    _api.setUnauthorizedHandler(_expireSession);
  }

  final ApiClient _api;
  final SessionStorage _sessionStorage;

  BackendUser? _user;
  Map<String, dynamic>? _accessData;
  Map<String, dynamic>? _loginContext;
  Map<String, dynamic>? _userPayload;

  bool isLoading = false;
  String? errorMessage;
  AppUserRole role = AppUserRole.unknown;
  SessionBootstrapState bootstrapState = SessionBootstrapState.checking;
  bool _bootstrapStarted = false;

  String? get session => _api.hasToken ? 'backend-token' : null;
  BackendUser? get user => _user;
  Map<String, dynamic>? get accessData => _accessData;
  Map<String, dynamic>? get loginContext => _loginContext;
  Map<String, dynamic>? get userPayload => _userPayload;
  bool get isAuthenticated => _user != null;
  bool get hasVerifiedEmail =>
      _userPayload?['has_verified_email'] == true ||
      (_userPayload?['email_verified_at']?.toString().isNotEmpty ?? false);
  bool get isBootstrapping => bootstrapState == SessionBootstrapState.checking;

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

      final token = _resolveToken(response);
      if (token == null || token.trim().isEmpty) {
        throw const ApiException('La respuesta no incluyó una sesión válida.');
      }
      _api.setToken(token);
      _storeSessionPayload(response, requireEffectiveRole: true);
      await _sessionStorage.writeToken(token);
      bootstrapState = SessionBootstrapState.authenticated;
      await PushNotificationsService.syncAuthenticatedDevice();
    } on ApiException catch (e) {
      await _clearLocalSession();
      errorMessage = _apiErrorMessage(e);
      bootstrapState = SessionBootstrapState.signedOut;
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
    bool identityValidationRequired = true,
    String identificationDocumentId = '',
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
        identityValidationRequired: identityValidationRequired,
        identificationDocumentId: identificationDocumentId.trim(),
        ineFront: ineFront,
        ineBack: ineBack,
        selfieBiometric: selfieBiometric,
      );

      final token = _resolveToken(response);
      if (token != null) _api.setToken(token);
      _storeSessionPayload(response, requireEffectiveRole: true);
      if (token != null) await _sessionStorage.writeToken(token);
      bootstrapState = SessionBootstrapState.authenticated;
      await PushNotificationsService.syncAuthenticatedDevice();
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
    String baseAirportCode = '',
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
        baseAirportCode: baseAirportCode.trim().toUpperCase(),
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
      _storeSessionPayload(response, requireEffectiveRole: true);
      if (token != null) await _sessionStorage.writeToken(token);
      bootstrapState = SessionBootstrapState.authenticated;
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
        await PushNotificationsService.revokeAuthenticatedDevice();
        await _api.logout();
      } catch (_) {
        // Limpiamos sesion local aunque el backend no responda.
      }
    }

    await _clearLocalSession();
    bootstrapState = SessionBootstrapState.signedOut;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> bootstrapSession({bool force = false}) async {
    if (_bootstrapStarted && !force) return;
    _bootstrapStarted = true;
    bootstrapState = SessionBootstrapState.checking;
    errorMessage = null;
    notifyListeners();

    final token = await _sessionStorage.readToken();
    if (token == null || token.trim().isEmpty) {
      await _clearLocalSession();
      bootstrapState = SessionBootstrapState.signedOut;
      notifyListeners();
      return;
    }

    _api.setToken(token);
    try {
      final response = await _api.me();
      _storeSessionPayload(response, requireEffectiveRole: true);
      bootstrapState = SessionBootstrapState.authenticated;
      await PushNotificationsService.syncAuthenticatedDevice();
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _clearLocalSession();
        bootstrapState = SessionBootstrapState.signedOut;
        errorMessage = 'Tu sesión venció. Inicia sesión nuevamente.';
      } else if (error.statusCode == 403) {
        bootstrapState = SessionBootstrapState.denied;
        errorMessage = 'No tienes permiso para acceder a esta aplicación.';
      } else if (error.message.contains('rol')) {
        await _clearLocalSession();
        bootstrapState = SessionBootstrapState.denied;
        errorMessage = error.message;
      } else {
        bootstrapState = SessionBootstrapState.offline;
        errorMessage = error.message;
      }
    } catch (_) {
      bootstrapState = SessionBootstrapState.offline;
      errorMessage = 'No fue posible validar la sesión. Revisa tu conexión.';
    }
    notifyListeners();
  }

  Future<void> _expireSession() async {
    await _clearLocalSession();
    bootstrapState = SessionBootstrapState.signedOut;
    errorMessage = 'Tu sesión venció. Inicia sesión nuevamente.';
    notifyListeners();
  }

  Future<void> _clearLocalSession() async {
    _api.setToken(null);
    await _sessionStorage.deleteToken();
    _user = null;
    _accessData = null;
    _loginContext = null;
    _userPayload = null;
    role = AppUserRole.unknown;
    await SessionCleanupRegistry.clearAll();
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
      _storeSessionPayload(response, requireEffectiveRole: true);
    } on ApiException catch (error) {
      if (error.statusCode == 401) await _expireSession();
      errorMessage = error.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void syncAccessState(Map<String, dynamic>? source) {
    _accessData = syncCommercialAccessPayload(_accessData, source);
    notifyListeners();
  }

  void consumeTrialQuote() {
    _accessData = consumeTrialQuoteLocally(_accessData);
    notifyListeners();
  }

  Future<void> refreshCommercialAccessStatus() async {
    if (!_api.hasToken) return;

    try {
      final response = await _api.getClientAccessStatus();
      syncAccessState(response);
    } catch (_) {
      // El flujo cliente debe seguir mostrando el ultimo snapshot si el backend no responde.
    }
  }

  Future<String> resendEmailVerification() async {
    final response = await _api.resendEmailVerification();
    return response['message']?.toString() ??
        'Enviamos un nuevo enlace de verificación.';
  }

  void _storeSessionPayload(
    Map<String, dynamic> response, {
    required bool requireEffectiveRole,
  }) {
    final data = _asMap(response['data']) ?? const {};
    final rawUser = response['user'] ?? data['user'] ?? data['account'];
    if (rawUser is! Map) {
      throw const ApiException('La respuesta no incluyo datos de usuario.');
    }

    final userJson = Map<String, dynamic>.from(rawUser);
    final loginContext = _asMap(
      response['login_context'] ??
          data['login_context'] ??
          data['loginContext'],
    );
    final effectiveRole = loginContext?['effective_role'];
    if (requireEffectiveRole && effectiveRole == null) {
      throw const ApiException(
        'La respuesta no incluyó el rol efectivo del usuario.',
      );
    }
    final resolvedRole = _roleFromDynamic(effectiveRole);
    if (resolvedRole == AppUserRole.unknown) {
      throw const ApiException('El rol de la cuenta no es compatible.');
    }

    final token = _resolveToken(response);
    if (token != null) _api.setToken(token);
    _userPayload = userJson;
    _accessData = _asMap(response['access'] ?? data['access']);
    _loginContext = loginContext;
    _user = BackendUser.fromJson(userJson);
    role = resolvedRole;
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
        details.addAll(
          messages.where((item) => item != null).map((item) {
            final field = entry.key == 'email' ? 'Correo' : entry.key;
            return '$field: $item';
          }),
        );
      }
    }

    return details.isEmpty
        ? error.message
        : '${error.message}\n${details.join('\n')}';
  }
}
