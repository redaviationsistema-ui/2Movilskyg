import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

import 'config/app_environment.dart';
import 'idempotency_key.dart';

class BackendUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String companyName;
  final String phone;

  const BackendUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.companyName,
    required this.phone,
  });

  factory BackendUser.fromJson(Map<String, dynamic> json) {
    return BackendUser(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'client',
      companyName: json['company_name']?.toString() ?? '',
      phone:
          json['phone']?.toString() ??
          (json['profile'] is Map
              ? (json['profile']['phone']?.toString() ?? '')
              : ''),
    );
  }
}

class ApiClient {
  ApiClient._({String? baseUrl, http.Client? httpClient})
    : _baseUrl = _resolveBaseUrl(baseUrl),
      _httpClient = httpClient ?? http.Client();

  ApiClient.forTesting({
    required String baseUrl,
    required http.Client httpClient,
  }) : _baseUrl = _resolveBaseUrl(baseUrl),
       _httpClient = httpClient;

  static final ApiClient instance = ApiClient._();
  static const Duration _requestTimeout = Duration(seconds: 35);
  static const Duration _multipartTimeout = Duration(seconds: 60);

  String? _token;
  final String _baseUrl;
  final http.Client _httpClient;
  Future<void> Function()? _unauthorizedHandler;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  String get baseUrl => _baseUrl;

  String get backendOrigin {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) return '';
    return uri.origin;
  }

  void setToken(String? token) {
    final normalized = token?.trim() ?? '';
    _token = normalized.isEmpty ? null : normalized;
  }

  void setUnauthorizedHandler(Future<void> Function()? handler) {
    _unauthorizedHandler = handler;
  }

  static String _resolveBaseUrl(String? explicit) {
    final value = (explicit ?? AppEnvironment.current.apiBaseUrl).trim();
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('API_BASE_URL no es una URL valida.');
    }
    if (uri.scheme != 'https' &&
        !const bool.fromEnvironment('ALLOW_HTTP_API')) {
      throw StateError('API_BASE_URL debe utilizar HTTPS.');
    }
    return value.replaceAll(RegExp(r'/+$'), '');
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return post('/auth/login', body: {'email': email, 'password': password});
  }

  Future<Map<String, dynamic>> forgotPassword(String email) => post(
    '/auth/forgot-password',
    body: {'email': email.trim().toLowerCase()},
  );

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String token,
    required String password,
  }) => post(
    '/auth/reset-password',
    body: {
      'email': email.trim().toLowerCase(),
      'token': token,
      'password': password,
      'password_confirmation': password,
    },
  );

  Future<Map<String, dynamic>> resendEmailVerification() =>
      post('/auth/verify-email');

  Future<Map<String, dynamic>> registerClient({
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
  }) {
    return postMultipartFirstAvailable(
      const ['/auth/register'],
      fields: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'role': 'client',
        'birth_date': birthDate,
        'nationality': nationality,
        'base': base,
        'city': base,
        'base_airport': base,
        'document_type': documentType,
        'document_number': documentNumber,
        'document_issue_date': documentIssueDate,
        'document_expiration': documentExpiration,
        'document_status': documentStatus,
        'identity_validation_required': identityValidationRequired ? '1' : '0',
        'identification_document_id': identificationDocumentId,
        'ine_curp': ineCurp,
        'ine_cic': ineCic,
        'ine_ocr': ineOcr,
        'ine_scan_raw': _limitTextPayload(ineScanRaw, 12000),
        'ine_scan_status': ineScanStatus,
        'identity_verification_status': identityVerificationStatus,
        'identity_verification_message': identityVerificationMessage,
        'identity_verified': identityVerified ? '1' : '0',
        'face_detected': faceDetected ? '1' : '0',
        'face_match_score': '',
        'liveness_score': '',
        'image_storage_score': biometricImageSaved ? '100' : '0',
        'biometric_image_saved': biometricImageSaved ? '1' : '0',
        'biometric_captured_at':
            biometricCapturedAt.isEmpty
                ? (selfieBiometric == null
                    ? ''
                    : DateTime.now().toIso8601String())
                : biometricCapturedAt,
        'biometric_provider': biometricProvider,
        'biometric_template_type': biometricTemplateType,
        'biometric_version': 'v1',
        'faces_count': facesCount.toString(),
        'face_confidence': faceConfidence?.toString() ?? '',
        'quality_brightness': qualityBrightness?.toString() ?? '',
        'quality_sharpness': qualitySharpness?.toString() ?? '',
        'pose_yaw': poseYaw?.toString() ?? '',
        'pose_pitch': posePitch?.toString() ?? '',
        'pose_roll': poseRoll?.toString() ?? '',
        'face_occluded': faceOccluded == null ? '' : (faceOccluded ? '1' : '0'),
      },
      files: {
        if (ineFront != null) 'ine_front': ineFront,
        if (ineBack != null) 'ine_back': ineBack,
        if (selfieBiometric != null) 'selfie_biometric': selfieBiometric,
      },
    );
  }

  Future<Map<String, dynamic>> storeRegistrationIdentification({
    required File file,
    required String fullName,
    required String phone,
    required String birthDate,
    required String documentNumber,
    required String nationality,
    required String curp,
    String documentName = 'Identificación oficial',
    String documentType = 'ine',
    String documentCategory = 'user_identification',
    String documentSlot = 'official_identification',
    bool requiresIdentityValidation = true,
    String expiresAt = '',
    String replaceDocumentId = '',
  }) {
    return postMultipartFirstAvailable(
      const ['/auth/registration/identification'],
      fields: {
        'document_name': documentName,
        'document_type': documentType,
        'document_category': documentCategory,
        'document_slot': documentSlot,
        'full_name': fullName,
        'phone': phone,
        'birth_date': birthDate,
        'document_number': documentNumber,
        'nationality': nationality,
        'curp': curp,
        'requires_identity_validation': requiresIdentityValidation ? '1' : '0',
        'expires_at': expiresAt,
        'replace_document_id': replaceDocumentId,
      },
      files: {'file': file},
    );
  }

  Future<Map<String, dynamic>> registerCrew({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    String base = '',
    String baseAirportCode = '',
    String birthDate = '',
    String nationality = '',
    String documentIssueDate = '',
    String documentStatus = '',
    String licenseType = 'Licencia de sobrecargo',
    String licenseCategory = '',
    String issuingCountry = '',
    String ineScanRaw = '',
    String ineScanStatus = '',
    String licenseNumber = '',
    String licenseExpiration = '',
    File? documentFront,
  }) {
    return postMultipartFirstAvailable(
      const ['/auth/register', '/crew/register', '/sobrecargo/register'],
      fields: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'role': 'provider',
        'operational_role': 'sobrecargo',
        'company_name': 'Red Aviation',
        'base': base,
        'base_airport': baseAirportCode.isEmpty ? base : baseAirportCode,
        'birth_date': birthDate,
        'nationality': nationality,
        'document_type': 'Licencia de sobrecargo',
        'document_number': licenseNumber,
        'document_issue_date': documentIssueDate,
        'document_expiration': licenseExpiration,
        'document_status': documentStatus,
        'identity_validation_required': '1',
        'ine_scan_raw': _limitTextPayload(ineScanRaw, 4000),
        'ine_scan_status': ineScanStatus,
        'license_type': licenseType,
        'license_number': licenseNumber,
        'license_category': licenseCategory,
        'license_birth_date': birthDate,
        'license_nationality': nationality,
        'license_issue_date': documentIssueDate,
        'license_expiration_date': licenseExpiration,
        'license_issuing_country': issuingCountry,
        'license_document_status': documentStatus,
      },
      files: {if (documentFront != null) 'license_file': documentFront},
    );
  }

  Future<Map<String, dynamic>> scanRegistrationDocument({
    required File document,
    String documentType = 'auto',
    String mergeMode = 'safe_overwrite',
  }) {
    return postMultipart(
      '/auth/ocr/scan-document',
      fields: {'document_type': documentType, 'merge_mode': mergeMode},
      files: {'documento': document},
    );
  }

  Future<Map<String, dynamic>> validateBiometricSelfie(File selfie) {
    return postMultipart(
      '/public/biometric/detect-face',
      fields: const {},
      files: {'selfie': selfie},
    );
  }

  Future<Map<String, dynamic>> me() {
    return get('/auth/me', authenticated: true);
  }

  Future<void> logout() async {
    await post('/auth/logout', authenticated: true);
  }

  Future<void> registerDevice({
    required String deviceUuid,
    required String platform,
    String? pushToken,
    String? appVersion,
  }) async {
    await post(
      '/auth/devices',
      authenticated: true,
      body: {
        'device_uuid': deviceUuid,
        'platform': platform,
        'push_token': pushToken,
        'app_version': appVersion,
      },
    );
  }

  Future<void> revokeDevice(String deviceUuid) async {
    await delete(
      '/auth/devices/${Uri.encodeComponent(deviceUuid)}',
      authenticated: true,
    );
  }

  Future<List<Map<String, dynamic>>> getAirports() async {
    final data = await get('/public/airports');
    return _asListOfMaps(data['airports']);
  }

  Future<List<Map<String, dynamic>>> getAircraftPreview() async {
    final data = await get('/public/aircraft-preview');
    return _asListOfMaps(data['aircraft']);
  }

  Future<Map<String, dynamic>> getClientDashboard() {
    return getFirstAvailable(const [
      '/cliente/dashboard',
      '/client/dashboard',
    ], authenticated: true);
  }

  Future<List<Map<String, dynamic>>> getReservations() async {
    final data = await getFirstAvailable(const [
      '/cliente/reservas',
      '/client/reservations',
      '/client/flight-requests',
    ], authenticated: true);
    return _listFromPayload(data, const [
      'reservations',
      'reservas',
      'bookings',
      'flight_requests',
      'requests',
      'solicitudes',
      'items',
      'data',
    ]);
  }

  Future<Map<String, dynamic>> getAuthorizedClientReservation(
    String reservationId,
  ) {
    final normalizedId = reservationId.trim();
    if (normalizedId.isEmpty) {
      throw const ApiException('La notificacion no contiene reservation_id.');
    }
    return getFirstAvailable([
      '/client/reservations/$normalizedId',
      '/cliente/reservas/$normalizedId',
    ], authenticated: true);
  }

  Future<List<Map<String, dynamic>>> getClientFlightRequests() async {
    final data = await getFirstAvailable(const [
      '/client/flight-requests',
      '/cliente/solicitudes',
      '/cliente/reservas',
      '/client/reservations',
    ], authenticated: true);

    return _listFromPayload(data, const [
      'flight_requests',
      'requests',
      'solicitudes',
      'reservations',
      'reservas',
      'bookings',
      'items',
      'data',
    ]);
  }

  Future<List<Map<String, dynamic>>> getClientAircraft({
    String? origin,
    int? passengers,
  }) async {
    try {
      final data = await get(
        '/client/aircraft',
        authenticated: true,
        query: {
          if (origin != null && origin.trim().isNotEmpty)
            'origin': origin.trim().toUpperCase(),
          if (origin != null && origin.trim().isNotEmpty)
            'base_airport': origin.trim().toUpperCase(),
          if (passengers != null && passengers > 0)
            'passengers': passengers.toString(),
        },
      );

      return _asListOfMaps(data['aircraft']);
    } on ApiException {
      return getAircraftPreview();
    }
  }

  Future<Map<String, dynamic>> previewClientQuotes({
    required String origin,
    required String destination,
    required DateTime departure,
    required int passengers,
    required String tripType,
    String? tripLabel,
    String? aircraftType,
    List<Map<String, dynamic>> requirements = const [],
    List<Map<String, dynamic>> legs = const [],
    String? flightPackage,
    String? priorityType,
    String? preference,
    String? pets,
    String? specialBaggage,
    String? notes,
  }) {
    return post(
      '/client/quotes/preview',
      authenticated: true,
      body: {
        'origin': origin,
        'destination': destination,
        'departure_datetime': departure.toIso8601String(),
        'passengers': passengers,
        'trip_type': tripType,
        'trip_label': tripLabel ?? _tripLabelForType(tripType),
        if (aircraftType != null && aircraftType.trim().isNotEmpty)
          'aircraft_type': aircraftType.trim(),
        if (flightPackage != null && flightPackage.trim().isNotEmpty)
          'flight_package': flightPackage.trim(),
        if (priorityType != null && priorityType.trim().isNotEmpty)
          'priority_type': priorityType.trim(),
        if (preference != null && preference.trim().isNotEmpty)
          'preference': preference.trim(),
        if (pets != null && pets.trim().isNotEmpty) 'pets': pets.trim(),
        if (specialBaggage != null && specialBaggage.trim().isNotEmpty)
          'special_baggage': specialBaggage.trim(),
        if (legs.isNotEmpty) 'legs': legs,
        if (requirements.isNotEmpty) 'requirements': requirements,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> previewClientQuotesPayload(
    Map<String, dynamic> payload,
  ) {
    return post('/client/quotes/preview', authenticated: true, body: payload);
  }

  Future<Map<String, dynamic>> createFlightRequest({
    required String origin,
    required String destination,
    required DateTime departure,
    required int passengers,
    required String tripType,
    String? tripLabel,
    String? notes,
    String? aircraftType,
    String? providerId,
    String? aircraftId,
    String? matchId,
    String? matchedOptionId,
    List<Map<String, dynamic>> requirements = const [],
    Map<String, dynamic> extraBody = const {},
  }) {
    return postFirstAvailable(
      const ['/client/flight-requests', '/cliente/solicitudes'],
      authenticated: true,
      body: {
        'origin': origin,
        'base_airport': origin,
        'destination': destination,
        'departure_datetime': departure.toIso8601String(),
        'passengers': passengers,
        'trip_type': tripType,
        'trip_label': tripLabel ?? _tripLabelForType(tripType),
        if (aircraftType != null && aircraftType.trim().isNotEmpty)
          'aircraft_type': aircraftType.trim(),
        if (providerId != null && providerId.isNotEmpty)
          'provider_id': providerId,
        if (aircraftId != null && aircraftId.isNotEmpty)
          'aircraft_id': aircraftId,
        if (matchId != null && matchId.isNotEmpty) 'match_id': matchId,
        if (matchedOptionId != null && matchedOptionId.isNotEmpty)
          'matched_option_id': matchedOptionId,
        if (requirements.isNotEmpty) 'requirements': requirements,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        ...extraBody,
      },
    );
  }

  Future<Map<String, dynamic>> createFlightRequestPayload(
    Map<String, dynamic> payload,
  ) {
    return postFirstAvailable(
      const ['/client/flight-requests', '/cliente/solicitudes'],
      authenticated: true,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> createClientReservation({
    required String flightRequestId,
  }) {
    final normalizedFlightRequestId = flightRequestId.trim();
    if (normalizedFlightRequestId.isEmpty) {
      throw const ApiException(
        'No existe flight_request asociado para crear la reserva.',
      );
    }

    return () async {
      try {
        return await postFirstAvailable(
          const ['/cliente/reservas', '/client/reservations'],
          authenticated: true,
          body: {'flight_request_id': normalizedFlightRequestId},
          headers: {
            'Idempotency-Key': IdempotencyKey.forOperation(
              'create-reservation',
              normalizedFlightRequestId,
            ),
          },
        );
      } on ApiException catch (error) {
        final status = error.statusCode ?? 0;
        if (status == 404) {
          throw ApiException(
            'No existe flight_request para crear la reserva.',
            statusCode: error.statusCode,
            cause: error,
            payload: error.payload,
          );
        }
        throw ApiException(
          'No fue posible crear reservation. ${error.message}',
          statusCode: error.statusCode,
          cause: error,
          payload: error.payload,
        );
      }
    }();
  }

  Future<String> ensureClientReservation({
    required String flightRequestId,
    String? existingReservationId,
  }) async {
    final normalizedReservationId = existingReservationId?.trim() ?? '';
    if (normalizedReservationId.isNotEmpty) {
      return normalizedReservationId;
    }

    final payload = await createClientReservation(
      flightRequestId: flightRequestId,
    );
    final reservationId = _firstTextValue(payload, const [
      'reservation_id',
      'reservationId',
      'booking_id',
      'bookingId',
      'id',
    ]);
    if (reservationId.isEmpty) {
      throw const ApiException(
        'No fue posible crear reservation porque el backend no devolvio reservation_id.',
      );
    }
    return reservationId;
  }

  Future<Map<String, dynamic>> signClientContract({
    required String reservationId,
    required Map<String, dynamic> contractPayload,
  }) {
    return postFirstAvailable(
      [
        '/cliente/reservas/$reservationId/contrato/firmar',
        '/client/reservations/$reservationId/contract/sign',
        '/cliente/solicitudes/$reservationId/contrato/firmar',
        '/client/flight-requests/$reservationId/contract/sign',
      ],
      authenticated: true,
      body: contractPayload,
    );
  }

  Future<Map<String, dynamic>> sendClientContractForSignature({
    required String reservationId,
    String? flightRequestId,
    required Map<String, dynamic> contractPayload,
  }) {
    final normalizedReservationId = reservationId.trim();
    final normalizedFlightRequestId = flightRequestId?.trim() ?? '';
    final paths = <String>[];

    void addPath(String value) {
      if (value.isEmpty || paths.contains(value)) return;
      paths.add(value);
    }

    if (normalizedReservationId.isNotEmpty) {
      addPath('/cliente/reservas/$normalizedReservationId/contrato/docusign');
      addPath(
        '/client/reservations/$normalizedReservationId/contract/docusign',
      );
      addPath('/cliente/reservas/$normalizedReservationId/contrato/enviar');
      addPath('/client/reservations/$normalizedReservationId/contract/send');
    }

    if (normalizedFlightRequestId.isNotEmpty) {
      // Some backends resolve reservation routes from flight_request_id.
      addPath('/cliente/reservas/$normalizedFlightRequestId/contrato/docusign');
      addPath(
        '/client/reservations/$normalizedFlightRequestId/contract/docusign',
      );
      addPath('/cliente/reservas/$normalizedFlightRequestId/contrato/enviar');
      addPath('/client/reservations/$normalizedFlightRequestId/contract/send');
      addPath(
        '/cliente/solicitudes/$normalizedFlightRequestId/contrato/docusign',
      );
      addPath(
        '/client/flight-requests/$normalizedFlightRequestId/contract/docusign',
      );
      addPath(
        '/cliente/solicitudes/$normalizedFlightRequestId/contrato/enviar',
      );
      addPath(
        '/client/flight-requests/$normalizedFlightRequestId/contract/send',
      );
    }

    final body = {
      if (normalizedReservationId.isNotEmpty)
        'reservation_id': normalizedReservationId,
      if (normalizedFlightRequestId.isNotEmpty)
        'flight_request_id': normalizedFlightRequestId,
      if (normalizedReservationId.isNotEmpty)
        'booking_id': normalizedReservationId,
      ...contractPayload,
    };

    return () async {
      try {
        return await writeFirstAvailable(
          paths,
          authenticated: true,
          body: body,
          headers: {
            'Idempotency-Key': IdempotencyKey.forOperation(
              'regenerate-contract',
              normalizedReservationId.isNotEmpty
                  ? normalizedReservationId
                  : normalizedFlightRequestId,
            ),
          },
        );
      } on ApiException catch (error) {
        final status = error.statusCode ?? 0;
        final attemptedPaths = paths.join(', ');
        if (status == 404 || status == 405) {
          throw ApiException(
            'No fue posible preparar DocuSign porque el backend no expone una ruta compatible para este contrato. Rutas probadas: $attemptedPaths',
            statusCode: error.statusCode,
            cause: error,
            payload: error.payload,
          );
        }
        throw ApiException(
          'No fue posible preparar DocuSign. ${error.message} Rutas probadas: $attemptedPaths',
          statusCode: error.statusCode,
          cause: error,
          payload: error.payload,
        );
      }
    }();
  }

  Future<Map<String, dynamic>> getClientContractStatus(String contractId) {
    final normalizedId = contractId.trim();
    if (normalizedId.isEmpty) {
      throw const ApiException(
        'No se encontro el identificador del contrato para consultar estado.',
      );
    }

    return getFirstAvailable([
      '/cliente/contratos/$normalizedId/estado',
      '/client/contracts/$normalizedId/status',
      '/contracts/$normalizedId/status',
    ], authenticated: true);
  }

  Future<Map<String, dynamic>> getClientContract({
    String reservationId = '',
    String flightRequestId = '',
  }) {
    final normalizedReservationId = reservationId.trim();
    final normalizedFlightRequestId = flightRequestId.trim();
    final paths = <String>[];

    void addPath(String value) {
      if (value.isEmpty || paths.contains(value)) return;
      paths.add(value);
    }

    if (normalizedReservationId.isNotEmpty) {
      addPath('/cliente/reservas/$normalizedReservationId/contrato');
      addPath('/client/reservations/$normalizedReservationId/contract');
    }

    if (normalizedFlightRequestId.isNotEmpty) {
      addPath('/cliente/solicitudes/$normalizedFlightRequestId/contrato');
      addPath('/client/flight-requests/$normalizedFlightRequestId/contract');
      addPath('/cliente/reservas/$normalizedFlightRequestId/contrato');
      addPath('/client/reservations/$normalizedFlightRequestId/contract');
    }

    if (paths.isEmpty) {
      throw const ApiException(
        'No se encontro un identificador valido para consultar el contrato.',
      );
    }

    return getFirstAvailable(paths, authenticated: true);
  }

  Future<Uint8List> downloadClientContractPdf(String reservationId) {
    return downloadFirstAvailable([
      '/cliente/reservas/$reservationId/contrato/pdf',
      '/cliente/reservas/$reservationId/contrato/download',
      '/cliente/reservas/$reservationId/contrato/descargar',
      '/client/reservations/$reservationId/contract/pdf',
      '/client/reservations/$reservationId/contract/download',
      '/client/flight-requests/$reservationId/contract/pdf',
    ], authenticated: true);
  }

  Future<Map<String, dynamic>> requestConcierge({
    required String message,
    String? reservationId,
    String? flightRequestId,
    String category = 'general',
  }) {
    return postFirstAvailable(
      const ['/client/concierge/request', '/cliente/concierge/request'],
      authenticated: true,
      body: {
        'message': message.trim(),
        'category': category,
        if (reservationId != null && reservationId.trim().isNotEmpty)
          'reservation_id': reservationId.trim(),
        if (flightRequestId != null && flightRequestId.trim().isNotEmpty)
          'flight_request_id': flightRequestId.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> createClientPaymentIntent({
    required String flightRequestId,
    required Map<String, dynamic> paymentPayload,
  }) {
    final body = {
      'flight_request_id': flightRequestId,
      'booking_id': flightRequestId,
      ...paymentPayload,
    };

    return postFirstAvailable(
      const [
        '/cliente/stripe/payment-intent',
        '/client/stripe/payment-intent',
        '/stripe/payment-intent',
      ],
      authenticated: true,
      body: body,
    );
  }

  Future<Map<String, dynamic>> createClientCheckout({
    required String flightRequestId,
    required Map<String, dynamic> paymentPayload,
    String successUrl = '',
    String cancelUrl = '',
    String returnUrl = '',
  }) {
    final body = {
      'flight_request_id': flightRequestId,
      'booking_id': flightRequestId,
      if (successUrl.trim().isNotEmpty) 'success_url': successUrl.trim(),
      if (cancelUrl.trim().isNotEmpty) 'cancel_url': cancelUrl.trim(),
      if (returnUrl.trim().isNotEmpty) 'return_url': returnUrl.trim(),
      ...paymentPayload,
    };
    final checkoutScope = [
      paymentPayload['reservation_id']?.toString().trim() ?? '',
      flightRequestId.trim(),
      paymentPayload['contact_email']?.toString().trim().toLowerCase() ?? '',
      paymentPayload['payment_method']?.toString().trim().toLowerCase() ?? '',
      successUrl.trim(),
      cancelUrl.trim(),
      returnUrl.trim(),
    ].join('|');

    return postFirstAvailable(
      const [
        '/cliente/stripe/checkout/create',
        '/client/stripe/checkout/create',
        '/stripe/checkout/create',
      ],
      authenticated: true,
      body: body,
      headers: {
        'Idempotency-Key': IdempotencyKey.forOperationWithScope(
          'create-checkout',
          paymentPayload['reservation_id']?.toString().trim().isNotEmpty == true
              ? paymentPayload['reservation_id'].toString()
              : flightRequestId,
          scope: checkoutScope,
        ),
      },
    );
  }

  Future<Map<String, dynamic>> getClientPaymentAuthorization({
    required String reservationId,
    String flightRequestId = '',
  }) {
    final normalizedReservationId = reservationId.trim();
    if (normalizedReservationId.isEmpty) {
      throw const ApiException(
        'No existe una reservacion para validar el pago.',
      );
    }
    return getFirstAvailable(
      [
        '/cliente/reservas/$normalizedReservationId/payment-authorization',
        '/cliente/reservas/$normalizedReservationId/autorizacion-pago',
      ],
      authenticated: true,
      query: {
        'reservation_id': normalizedReservationId,
        if (flightRequestId.trim().isNotEmpty)
          'flight_request_id': flightRequestId.trim(),
      },
      fallbackStatusCodes: const {404, 405},
    );
  }

  Future<Map<String, dynamic>> getClientCheckoutSuccess({
    String? sessionId,
    String? reservationId,
    String? flightRequestId,
  }) {
    final query = <String, String>{
      if (sessionId != null && sessionId.trim().isNotEmpty)
        'session_id': sessionId.trim(),
      if (sessionId != null && sessionId.trim().isNotEmpty)
        'checkout_session_id': sessionId.trim(),
      if (sessionId != null && sessionId.trim().isNotEmpty)
        'stripe_checkout_session_id': sessionId.trim(),
      if (reservationId != null && reservationId.trim().isNotEmpty)
        'reservation_id': reservationId.trim(),
      if (reservationId != null && reservationId.trim().isNotEmpty)
        'booking_id': reservationId.trim(),
      if (flightRequestId != null && flightRequestId.trim().isNotEmpty)
        'flight_request_id': flightRequestId.trim(),
      if (flightRequestId != null && flightRequestId.trim().isNotEmpty)
        'request_id': flightRequestId.trim(),
    };

    return getFirstAvailable(
      const [
        '/cliente/stripe/checkout/success',
        '/client/stripe/checkout/success',
        '/stripe/checkout/success',
      ],
      authenticated: true,
      query: query,
      fallbackStatusCodes: const {404, 405},
    );
  }

  Future<Map<String, dynamic>> cancelClientCheckout({String? sessionId}) {
    final query = <String, String>{
      if (sessionId != null && sessionId.trim().isNotEmpty)
        'session_id': sessionId.trim(),
    };

    return getFirstAvailable(
      const [
        '/cliente/stripe/checkout/cancel',
        '/client/stripe/checkout/cancel',
        '/stripe/checkout/cancel',
      ],
      authenticated: true,
      query: query,
    );
  }

  Future<Map<String, dynamic>> createClientWireIntent({
    required String flightRequestId,
    required Map<String, dynamic> paymentPayload,
  }) {
    final body = {
      'flight_request_id': flightRequestId,
      'booking_id': flightRequestId,
      ...paymentPayload,
    };

    return postFirstAvailable(
      const [
        '/cliente/stripe/wire-intent',
        '/client/stripe/wire-intent',
        '/stripe/wire-intent',
      ],
      authenticated: true,
      body: body,
    );
  }

  Future<Map<String, dynamic>> confirmClientPaymentIntent({
    required String flightRequestId,
    required Map<String, dynamic> paymentPayload,
  }) {
    final body = {
      'flight_request_id': flightRequestId,
      'booking_id': flightRequestId,
      ...paymentPayload,
    };

    return postFirstAvailable(
      const [
        '/cliente/stripe/payment-intent/confirm',
        '/client/stripe/payment-intent/confirm',
        '/stripe/payment-intent/confirm',
      ],
      authenticated: true,
      body: body,
      headers: {
        'Idempotency-Key': IdempotencyKey.forOperation(
          'confirm-payment',
          paymentPayload['reservation_id']?.toString().trim().isNotEmpty == true
              ? paymentPayload['reservation_id'].toString()
              : flightRequestId,
        ),
      },
    );
  }

  Future<Map<String, dynamic>> confirmClientPayment({
    required String reservationId,
    required Map<String, dynamic> paymentPayload,
  }) {
    return postFirstAvailable(
      [
        '/cliente/reservas/$reservationId/pago/confirmar',
        '/cliente/reservas/$reservationId/payment/confirm',
        '/client/reservations/$reservationId/payment/confirm',
        '/client/reservations/$reservationId/payments/confirm',
        '/cliente/solicitudes/$reservationId/pago/confirmar',
        '/cliente/solicitudes/$reservationId/payment/confirm',
        '/client/flight-requests/$reservationId/payment/confirm',
        '/client/flight-requests/$reservationId/payments/confirm',
      ],
      authenticated: true,
      body: paymentPayload,
      headers: {
        'Idempotency-Key': IdempotencyKey.forOperation(
          'confirm-payment',
          reservationId,
        ),
      },
    );
  }

  Future<Map<String, dynamic>> createClientAccessCheckout({
    required Map<String, dynamic> paymentPayload,
    String successUrl = '',
    String cancelUrl = '',
    String returnUrl = '',
  }) {
    return postFirstAvailable(
      const ['/client/access-payment/create', '/cliente/access-payment/create'],
      authenticated: true,
      body: {
        if (successUrl.trim().isNotEmpty) 'success_url': successUrl.trim(),
        if (cancelUrl.trim().isNotEmpty) 'cancel_url': cancelUrl.trim(),
        if (returnUrl.trim().isNotEmpty) 'return_url': returnUrl.trim(),
        ...paymentPayload,
      },
    );
  }

  Future<Map<String, dynamic>> getClientAccessPaymentSuccess({
    String? sessionId,
    String? contactEmail,
  }) {
    final query = <String, String>{
      if (sessionId != null && sessionId.trim().isNotEmpty) ...{
        'session_id': sessionId.trim(),
        'checkout_session_id': sessionId.trim(),
        'checkoutSessionId': sessionId.trim(),
        'sessionId': sessionId.trim(),
        'stripe_session_id': sessionId.trim(),
      },
      if (contactEmail != null && contactEmail.trim().isNotEmpty) ...{
        'contact_email': contactEmail.trim(),
        'email': contactEmail.trim(),
        'customer_email': contactEmail.trim(),
      },
    };

    return getFirstAvailable(
      const [
        '/client/access-payment/success',
        '/cliente/access-payment/success',
        '/access-payment/success',
        '/stripe/access-payment/success',
      ],
      authenticated: true,
      query: query,
    );
  }

  Future<Map<String, dynamic>> cancelClientAccessPayment({String? sessionId}) {
    final query = <String, String>{
      if (sessionId != null && sessionId.trim().isNotEmpty)
        'session_id': sessionId.trim(),
    };

    return getFirstAvailable(
      const ['/client/access-payment/cancel', '/cliente/access-payment/cancel'],
      authenticated: true,
      query: query,
    );
  }

  Future<Map<String, dynamic>> getClientAccessStatus() {
    return getFirstAvailable(const [
      '/client/access-status',
      '/cliente/access-status',
    ], authenticated: true);
  }

  Future<Map<String, dynamic>> getCrewPortal() {
    return getFirstAvailable(const [
      '/crew/portal',
      '/sobrecargo/portal',
      '/crew/dashboard',
      '/sobrecargo/dashboard',
    ], authenticated: true);
  }

  Future<Map<String, dynamic>> getCrewDashboard() {
    return getFirstAvailable(const [
      '/sobrecargo/dashboard',
      '/crew/dashboard',
      '/crew/portal',
    ], authenticated: true);
  }

  Future<Map<String, dynamic>> getCrewAssignments() {
    return getFirstAvailable(const [
      '/sobrecargo/assignments',
      '/crew/assignments',
      '/sobrecargo/operations',
      '/crew/operations',
    ], authenticated: true);
  }

  Future<Map<String, dynamic>> getCrewProfile() {
    return getFirstAvailable(const [
      '/sobrecargo/profile',
      '/crew/profile',
    ], authenticated: true);
  }

  Future<Map<String, dynamic>> getCrewDocuments() {
    return getFirstAvailable(const [
      '/sobrecargo/documents',
      '/crew/documents',
    ], authenticated: true);
  }

  Future<Map<String, dynamic>> getCrewIncidents({String? operationId}) {
    return getFirstAvailable(
      const [
        '/crew-operation-incidents',
        '/sobrecargo/incidents',
        '/sobrecargo/incidencias',
      ],
      authenticated: true,
      query: {
        if (operationId != null && operationId.trim().isNotEmpty)
          'crew_operation_id': operationId.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> respondCrewAssignment({
    required String assignmentId,
    required String status,
    String reason = '',
  }) {
    final payload = _crewAssignmentResponsePayload(status, reason);
    return postFirstAvailable(
      [
        '/sobrecargo/operations/$assignmentId/respond',
        '/sobrecargo/assignments/$assignmentId/respond',
        '/sobrecargo/operations/$assignmentId/assignment-response',
        '/crew/assignments/$assignmentId/respond',
        '/sobrecargo/asignaciones/$assignmentId/responder',
        '/admin/crew-assignments/$assignmentId/respond',
      ],
      authenticated: true,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> updateCrewOperationStep({
    required String assignmentId,
    required String step,
    String note = '',
  }) async {
    final normalizedNote = note.trim();
    final stepVariants = switch (step) {
      'checkin' => const ['checkin'],
      'cabin_ready' => const ['cabin-ready', 'cabin_ready'],
      'passengers_ready' => const ['passengers-ready', 'passengers_ready'],
      'service_started' => const [
        'start-service',
        'service-started',
        'service_started',
      ],
      'service_finalized' => const [
        'finalize-service',
        'service-finalized',
        'service_finalized',
        'complete-service',
        'complete_service',
        'completed',
      ],
      _ => [step],
    };

    final statusHints = switch (step) {
      'checkin' => const ['crew_enroute'],
      'cabin_ready' => const ['cabin_ready', 'cabin ready'],
      'passengers_ready' => const ['passengers_ready', 'passengers ready'],
      'service_started' => const [
        'service_started',
        'service started',
        'crew_active',
      ],
      'service_finalized' => const [
        'completed',
        'service_finalized',
        'service finalized',
        'crew_completed',
        'finalizada',
      ],
      _ => [step],
    };

    ApiException? lastError;

    for (final pathStep in stepVariants) {
      final paths = [
        '/sobrecargo/operations/$assignmentId/$pathStep',
        '/sobrecargo/assignments/$assignmentId/$pathStep',
        '/crew/operations/$assignmentId/$pathStep',
        '/crew/assignments/$assignmentId/$pathStep',
        '/sobrecargo/operations/$assignmentId/steps/$pathStep',
        '/sobrecargo/assignments/$assignmentId/steps/$pathStep',
        '/crew/operations/$assignmentId/steps/$pathStep',
        '/crew/assignments/$assignmentId/steps/$pathStep',
      ];

      for (final statusHint in statusHints) {
        try {
          return await writeFirstAvailable(
            paths,
            authenticated: true,
            body: {
              'step': step,
              'status': statusHint,
              'crew_status': statusHint,
              'workflow_status': statusHint,
              if (normalizedNote.isNotEmpty) 'note': normalizedNote,
              if (normalizedNote.isNotEmpty) 'notes': normalizedNote,
              if (normalizedNote.isNotEmpty) 'comment': normalizedNote,
            },
          );
        } on ApiException catch (error) {
          lastError = error;
        }
      }
    }

    throw lastError ??
        const ApiException('No fue posible completar la solicitud.');
  }

  Future<Map<String, dynamic>> createCrewAvailabilityBlock({
    required DateTime startsAt,
    required DateTime endsAt,
    required String reason,
  }) {
    return saveCrewAvailabilityDay(
      date: startsAt,
      statusKey: 'BLOQUEO_SOLICITADO',
      comment: reason,
    );
  }

  Future<Map<String, dynamic>> getCrewAvailability({
    required DateTime from,
    required DateTime to,
  }) {
    return getFirstAvailable(
      const ['/sobrecargo/availability', '/crew/availability'],
      authenticated: true,
      query: {'from': _apiDate(from), 'to': _apiDate(to)},
    );
  }

  Future<Map<String, dynamic>> getCrewAvailabilityStatuses() {
    return getFirstAvailable(const [
      '/sobrecargo/availability/statuses',
      '/crew/availability/statuses',
    ], authenticated: true);
  }

  Future<Map<String, dynamic>> saveCrewAvailabilityDay({
    required DateTime date,
    required String statusKey,
    String comment = '',
    String base = '',
    String coverage = '',
  }) {
    final normalizedStatus = statusKey.trim().toUpperCase();
    final normalizedComment = comment.trim();
    final statusLabel = _humanizeAvailabilityStatus(normalizedStatus);
    return postFirstAvailable(
      const ['/sobrecargo/availability', '/crew/availability'],
      authenticated: true,
      body: {
        'fecha': _apiDate(date),
        'date': _apiDate(date),
        'from': _apiDate(date),
        'to': _apiDate(date),
        'fecha_inicio': _apiDate(date),
        'fecha_fin': _apiDate(date),
        'status_key': normalizedStatus,
        'clave': normalizedStatus,
        'status': statusLabel,
        'state': statusLabel,
        'motivo': normalizedComment,
        'comentario': normalizedComment,
        'comment': normalizedComment,
        'notes': normalizedComment,
        if (base.trim().isNotEmpty) 'base': base.trim(),
        if (coverage.trim().isNotEmpty) 'coverage': coverage.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> auditCrewAvailabilityDay({
    required DateTime date,
    required String statusKey,
    String comment = '',
  }) {
    final normalizedStatus = statusKey.trim().toUpperCase();
    final normalizedComment = comment.trim();
    final dateLabel = _apiDate(date);
    return postFirstAvailable(
      const ['/sobrecargo/availability/audit', '/crew/availability/audit'],
      authenticated: true,
      body: {
        'fecha': dateLabel,
        'from': dateLabel,
        'to': dateLabel,
        'status_key': normalizedStatus,
        'clave': normalizedStatus,
        'comment': normalizedComment,
        'comentario': normalizedComment,
        'note':
            'Disponibilidad $dateLabel: ${_humanizeAvailabilityStatus(normalizedStatus)}.'
            '${normalizedComment.isEmpty ? '' : ' $normalizedComment'}',
      },
    );
  }

  String _humanizeAvailabilityStatus(String statusKey) {
    switch (statusKey.trim().toUpperCase()) {
      case 'DISPONIBLE':
        return 'Disponible';
      case 'NO_DISPONIBLE':
        return 'No disponible';
      case 'DESCANSO':
        return 'Descanso';
      case 'EN_OPERACION':
        return 'En operacion';
      case 'BLOQUEO_SOLICITADO':
        return 'Bloqueo solicitado';
      case 'BLOQUEO_APROBADO':
        return 'Bloqueo aprobado';
      case 'BLOQUEO_RECHAZADO':
        return 'Bloqueo rechazado';
      case 'POR_CONFIRMAR':
        return 'Por confirmar';
      default:
        return statusKey.trim();
    }
  }

  Future<Map<String, dynamic>> deleteCrewAvailability(String availabilityId) {
    return delete(
      '/sobrecargo/availability/$availabilityId',
      authenticated: true,
    );
  }

  Future<Map<String, dynamic>> createCrewIncident({
    required String assignmentId,
    required String title,
    required String description,
    File? evidence,
  }) {
    return postMultipartFirstAvailable(
      const ['/crew/incidents', '/sobrecargo/incidencias'],
      authenticated: true,
      fields: {
        'assignment_id': assignmentId,
        'title': title,
        'description': description,
        'status': 'open',
      },
      files: {if (evidence != null) 'evidence': evidence},
    );
  }

  String _tripLabelForType(String tripType) {
    switch (tripType) {
      case 'round_trip':
        return 'Redondo';
      case 'multi_leg':
        return 'Multi-destino';
      default:
        return 'Ida';
    }
  }

  String _limitTextPayload(String value, int maxLength) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '';
    return normalized.length > maxLength
        ? normalized.substring(0, maxLength)
        : normalized;
  }

  String _apiDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Map<String, dynamic> _crewAssignmentResponsePayload(
    String status,
    String reason,
  ) {
    final normalized = status.trim();
    final lower = normalized.toLowerCase();
    final response =
        lower == 'accepted' || lower == 'aceptado' || lower == 'confirmado'
            ? 'Confirmado'
            : lower == 'rejected' || lower == 'declined' || lower == 'rechazado'
            ? 'Rechazado'
            : lower == 'review_requested' ||
                lower == 'requested_changes' ||
                lower == 'solicitar revision'
            ? 'Solicitar revision'
            : normalized;
    final crewStatus = switch (response) {
      'Confirmado' => 'crew_confirmed',
      'Rechazado' => 'crew_declined',
      'Solicitar revision' => 'crew_change_requested',
      _ => '',
    };
    final trimmedReason = reason.trim();

    return {
      'response': response,
      'status': crewStatus.isEmpty ? response : crewStatus,
      'crew_status': crewStatus,
      if (trimmedReason.isNotEmpty) 'reason': trimmedReason,
      if (trimmedReason.isNotEmpty) 'reject_reason': trimmedReason,
      if (trimmedReason.isNotEmpty) 'comment': trimmedReason,
    };
  }

  Future<Map<String, dynamic>> getFirstAvailable(
    List<String> paths, {
    bool authenticated = false,
    Map<String, String>? query,
    Set<int>? fallbackStatusCodes,
  }) async {
    ApiException? lastError;

    for (final path in paths) {
      try {
        return await get(path, authenticated: authenticated, query: query);
      } on ApiException catch (error) {
        if (!_shouldTryAlternative(error, fallbackStatusCodes)) rethrow;
        lastError = error;
      }
    }

    throw lastError ??
        const ApiException('No fue posible completar la solicitud.');
  }

  Future<Map<String, dynamic>> postFirstAvailable(
    List<String> paths, {
    Map<String, dynamic>? body,
    bool authenticated = false,
    Map<String, String>? headers,
  }) async {
    ApiException? lastError;

    for (final path in paths) {
      try {
        return await post(
          path,
          body: body,
          authenticated: authenticated,
          headers: headers,
        );
      } on ApiException catch (error) {
        if (!_shouldTryAlternative(error, null)) rethrow;
        lastError = error;
      }
    }

    throw lastError ??
        const ApiException('No fue posible completar la solicitud.');
  }

  Future<Map<String, dynamic>> writeFirstAvailable(
    List<String> paths, {
    Map<String, dynamic>? body,
    bool authenticated = false,
    Map<String, String>? headers,
  }) async {
    ApiException? lastError;

    for (final path in paths) {
      for (final method in const ['POST', 'PATCH', 'PUT']) {
        try {
          return await _request(
            path,
            method: method,
            authenticated: authenticated,
            body: body,
            headers: headers,
          );
        } on ApiException catch (error) {
          if (!_shouldTryAlternative(error, null)) rethrow;
          lastError = error;
        }
      }
    }

    throw lastError ??
        const ApiException('No fue posible completar la solicitud.');
  }

  Future<Map<String, dynamic>> postMultipartFirstAvailable(
    List<String> paths, {
    required Map<String, String> fields,
    Map<String, File> files = const {},
    bool authenticated = false,
  }) async {
    ApiException? lastError;

    for (final path in paths) {
      try {
        return await postMultipart(
          path,
          fields: fields,
          files: files,
          authenticated: authenticated,
        );
      } on ApiException catch (error) {
        if (!_shouldTryAlternative(error, null)) rethrow;
        lastError = error;
      }
    }

    throw lastError ??
        const ApiException('No fue posible completar la solicitud.');
  }

  Future<Uint8List> downloadFirstAvailable(
    List<String> paths, {
    bool authenticated = false,
    Map<String, String>? query,
  }) async {
    ApiException? lastError;

    for (final path in paths) {
      try {
        return await download(path, authenticated: authenticated, query: query);
      } on ApiException catch (error) {
        if (!_shouldTryAlternative(error, null)) rethrow;
        lastError = error;
      }
    }

    throw lastError ??
        const ApiException('No fue posible descargar el documento.');
  }

  Future<Uint8List> download(
    String path, {
    bool authenticated = false,
    Map<String, String>? query,
  }) async {
    final response = await _send(
      baseUrl,
      path,
      method: 'GET',
      authenticated: authenticated,
      query: query,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      Map<String, dynamic> decoded = const {};
      try {
        decoded =
            response.body.isEmpty
                ? const {}
                : (jsonDecode(response.body) as Map<String, dynamic>);
      } catch (_) {
        decoded = {
          'raw_body': response.body,
          'content_type': response.headers['content-type'],
        };
      }
      if (response.statusCode == 401 && _unauthorizedHandler != null) {
        unawaited(_unauthorizedHandler!.call());
      }
      throw ApiException(
        ApiErrorMapper.messageFor(response.statusCode, decoded),
        statusCode: response.statusCode,
        payload: decoded,
      );
    }

    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = false,
    Map<String, String>? query,
  }) async {
    return _request(
      path,
      method: 'GET',
      authenticated: authenticated,
      query: query,
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
    Map<String, String>? headers,
  }) async {
    return _request(
      path,
      method: 'POST',
      authenticated: authenticated,
      body: body,
      headers: headers,
    );
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool authenticated = false,
  }) async {
    return _request(path, method: 'DELETE', authenticated: authenticated);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    return _request(
      path,
      method: 'PATCH',
      authenticated: authenticated,
      body: body,
    );
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    return _request(
      path,
      method: 'PUT',
      authenticated: authenticated,
      body: body,
    );
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    Map<String, File> files = const {},
    bool authenticated = false,
  }) async {
    final uri = _uri(baseUrl, path, null);
    final request =
        http.MultipartRequest('POST', uri)
          ..headers.addAll(_multipartHeaders(authenticated: authenticated))
          ..fields.addAll(fields);

    for (final entry in files.entries) {
      request.files.add(await _buildMultipartFile(entry.key, entry.value));
    }

    if (AppEnvironment.current.allowsDiagnosticLogs) {
      debugPrint(
        '[API multipart] path=$path fields=${fields.keys.toList()} fileFields=${files.keys.toList()}',
      );
    }
    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await request.send().timeout(_multipartTimeout);
    } on TimeoutException catch (error) {
      throw ApiException(
        'La carga de archivos excedio el tiempo de espera. Verifica tu conexion e intenta de nuevo.',
        cause: error,
      );
    } on SocketException catch (error) {
      throw ApiException(
        'No fue posible conectar con el servidor para subir archivos.',
        cause: error,
      );
    } on HttpException catch (error) {
      throw ApiException(
        'La carga de archivos fallo antes de completarse.',
        cause: error,
      );
    }

    http.Response response;
    try {
      response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(_multipartTimeout);
    } on TimeoutException catch (error) {
      throw ApiException(
        'La respuesta del servidor por la carga de archivos tardo demasiado.',
        cause: error,
      );
    }
    return _decode(response, baseUrl);
  }

  Future<http.MultipartFile> _buildMultipartFile(
    String fieldName,
    File file,
  ) async {
    final bytes = await file.readAsBytes();
    final fileName = _normalizedUploadFileName(file);
    final contentType = _contentTypeForFile(fileName);

    debugPrint(
      '[API multipart] file path=${file.path} name=$fileName bytes=${bytes.length} field=$fieldName contentType=${contentType.mimeType}',
    );

    return http.MultipartFile.fromBytes(
      fieldName,
      bytes,
      filename: fileName,
      contentType: contentType,
    );
  }

  String _normalizedUploadFileName(File file) {
    final originalName = path.basename(file.path).trim();
    final extension = path.extension(originalName).toLowerCase();

    if (extension == '.jpg' || extension == '.jpeg') return originalName;

    return '${path.basenameWithoutExtension(originalName)}.jpg';
  }

  MediaType _contentTypeForFile(String fileName) {
    final extension = path.extension(fileName).toLowerCase();
    return switch (extension) {
      '.jpg' || '.jpeg' => MediaType('image', 'jpeg'),
      '.png' => MediaType('image', 'png'),
      '.heic' => MediaType('image', 'heic'),
      '.pdf' => MediaType('application', 'pdf'),
      _ => MediaType('application', 'octet-stream'),
    };
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    required String method,
    required bool authenticated,
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    final response = await _send(
      baseUrl,
      path,
      method: method,
      authenticated: authenticated,
      body: body,
      query: query,
      headers: headers,
    );
    return _decode(response, baseUrl);
  }

  Future<http.Response> _send(
    String candidate,
    String path, {
    required String method,
    required bool authenticated,
    Map<String, dynamic>? body,
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    final uri = _uri(candidate, path, query);
    final requestHeaders = {
      ..._headers(authenticated: authenticated),
      ...?headers,
    };
    if (_shouldLogQuoteTraffic(path)) {}

    switch (method) {
      case 'POST':
        final response = await _guardHttpRequest(
          () => _httpClient.post(
            uri,
            headers: requestHeaders,
            body: jsonEncode(body ?? {}),
          ),
        );
        _logHttpResponse(method: method, uri: uri, response: response);
        return response;
      case 'PATCH':
        final response = await _guardHttpRequest(
          () => _httpClient.patch(
            uri,
            headers: requestHeaders,
            body: jsonEncode(body ?? {}),
          ),
        );
        _logHttpResponse(method: method, uri: uri, response: response);
        return response;
      case 'PUT':
        final response = await _guardHttpRequest(
          () => _httpClient.put(
            uri,
            headers: requestHeaders,
            body: jsonEncode(body ?? {}),
          ),
        );
        _logHttpResponse(method: method, uri: uri, response: response);
        return response;
      case 'DELETE':
        final response = await _guardHttpRequest(
          () => _httpClient.delete(uri, headers: requestHeaders),
        );
        _logHttpResponse(method: method, uri: uri, response: response);
        return response;
      default:
        final response = await _guardHttpRequest(
          () => _httpClient.get(uri, headers: requestHeaders),
        );
        _logHttpResponse(method: method, uri: uri, response: response);
        return response;
    }
  }

  Future<http.Response> _guardHttpRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException catch (error) {
      throw ApiException(
        'El servidor tardo demasiado en responder. Intenta de nuevo.',
        cause: error,
      );
    } on SocketException catch (error) {
      throw ApiException(
        'No fue posible conectar con el servidor.',
        cause: error,
      );
    } on HttpException catch (error) {
      throw ApiException(
        'La conexion con el servidor se interrumpio.',
        cause: error,
      );
    }
  }

  Uri _uri(String candidateBaseUrl, String path, Map<String, String>? query) {
    final uri = Uri.parse('${_normalizeBaseUrl(candidateBaseUrl)}$path');

    if (query == null || query.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  String _normalizeBaseUrl(String value) {
    return value.replaceAll(RegExp(r'/+$'), '');
  }

  void _logHttpResponse({
    required String method,
    required Uri uri,
    required http.Response response,
  }) {
    if (_shouldLogQuoteTraffic(uri.path)) {}
  }

  bool _shouldLogQuoteTraffic(String path) {
    final normalizedPath = path.trim().toLowerCase();
    return normalizedPath.endsWith('/client/quotes/preview');
  }

  Map<String, String> _headers({required bool authenticated}) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (authenticated && hasToken) 'Authorization': 'Bearer $_token',
    };
  }

  Map<String, String> _multipartHeaders({required bool authenticated}) {
    return {
      'Accept': 'application/json',
      if (authenticated && hasToken) 'Authorization': 'Bearer $_token',
    };
  }

  bool _shouldTryAlternative(
    ApiException error,
    Set<int>? fallbackStatusCodes,
  ) {
    final status = error.statusCode ?? 0;
    if (fallbackStatusCodes != null) {
      return fallbackStatusCodes.contains(status);
    }
    return status == 0 || status == 404 || status == 405 || status >= 500;
  }

  Map<String, dynamic> _decode(
    http.Response response,
    String candidateBaseUrl,
  ) {
    dynamic decodedRaw;
    try {
      decodedRaw =
          response.body.isEmpty
              ? <String, dynamic>{}
              : jsonDecode(response.body);
    } on FormatException catch (error) {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'El servidor devolvio una respuesta invalida (HTTP ${response.statusCode}).',
          statusCode: response.statusCode,
          cause: error,
          payload: {
            'raw_body': response.body,
            'content_type': response.headers['content-type'],
          },
        );
      }
      throw ApiException(
        'La respuesta del servidor no se pudo interpretar correctamente.',
        statusCode: response.statusCode,
        cause: error,
        payload: {
          'raw_body': response.body,
          'content_type': response.headers['content-type'],
        },
      );
    }
    final Map<String, dynamic> decoded =
        decodedRaw is Map<String, dynamic>
            ? decodedRaw
            : decodedRaw is Map
            ? Map<String, dynamic>.from(decodedRaw)
            : decodedRaw is List
            ? <String, dynamic>{'data': decodedRaw}
            : <String, dynamic>{'data': decodedRaw};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 && _unauthorizedHandler != null) {
        unawaited(_unauthorizedHandler!.call());
      }
      throw ApiException(
        ApiErrorMapper.messageFor(response.statusCode, decoded),
        statusCode: response.statusCode,
        payload: decoded,
      );
    }

    if (decoded['success'] == false) {
      throw ApiException(decoded['message']?.toString() ?? 'Solicitud fallida');
    }

    return decoded;
  }

  String _firstTextValue(Map<String, dynamic>? payload, List<String> keys) {
    if (payload == null) return '';
    for (final key in keys) {
      final value = payload[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }

    final data = payload['data'];
    if (data is Map) {
      final value = _firstTextValue(Map<String, dynamic>.from(data), keys);
      if (value.isNotEmpty) return value;
    }

    final reservation = payload['reservation'];
    if (reservation is Map) {
      final value = _firstTextValue(
        Map<String, dynamic>.from(reservation),
        keys,
      );
      if (value.isNotEmpty) return value;
    }

    return '';
  }

  List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _listFromPayload(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    for (final key in keys) {
      final list = _deepListOfMaps(payload[key]);
      if (list.isNotEmpty || payload.containsKey(key)) return list;
    }

    return _deepListOfMaps(payload);
  }

  List<Map<String, dynamic>> _deepListOfMaps(dynamic value) {
    if (value is List) return _asListOfMaps(value);
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final key in const [
        'data',
        'items',
        'results',
        'records',
        'reservations',
        'reservas',
        'flight_requests',
        'requests',
      ]) {
        final list = _deepListOfMaps(map[key]);
        if (list.isNotEmpty) return list;
      }
    }
    return const [];
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? cause;
  final Map<String, dynamic>? payload;

  const ApiException(this.message, {this.statusCode, this.cause, this.payload});

  bool get isAircraftAvailabilityConflict {
    if (statusCode != 409) return false;
    final values = [
      payload?['code'],
      payload?['error_code'],
      payload?['error'],
      payload?['message'],
      message,
    ];
    return values.any((value) {
      final normalized = value.toString().toUpperCase();
      return normalized.contains('AIRCRAFT_NOT_AVAILABLE') ||
          normalized.contains('AIRCRAFT_ALREADY_RESERVED');
    });
  }

  bool get isAircraftNotAvailable => isAircraftAvailabilityConflict;

  @override
  String toString() => message;
}

class ApiErrorMapper {
  const ApiErrorMapper._();

  static String messageFor(int statusCode, Map<String, dynamic> payload) {
    switch (statusCode) {
      case 401:
        return 'Tu sesión venció. Inicia sesión nuevamente.';
      case 403:
        return 'No tienes permiso para realizar esta acción.';
      case 404:
        return 'No se encontró la información solicitada.';
      case 409:
        return payload['message']?.toString() ??
            'La información cambió. Actualiza e inténtalo nuevamente.';
      case 422:
        return payload['message']?.toString() ?? 'Revisa los datos capturados.';
      case 429:
        return 'Has realizado demasiados intentos. Espera unos minutos e inténtalo nuevamente.';
      default:
        if (statusCode >= 500) {
          return 'No fue posible completar la operación. Inténtalo nuevamente.';
        }
        return payload['message']?.toString() ?? 'Solicitud fallida.';
    }
  }
}
