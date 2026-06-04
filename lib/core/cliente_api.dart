import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

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
  ApiClient._();

  static final ApiClient instance = ApiClient._();
  static const String _defaultBaseUrl =
      'https://uber-aviones.onrender.com/api/v1/';

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _configuredFallbackBaseUrl = String.fromEnvironment(
    'FALLBACK_API_BASE_URL',
    defaultValue: '',
  );

  String? _token;
  int _activeBackendIndex = 0;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  String get baseUrl => _backendCandidates[_activeBackendIndex];

  List<String> get _backendCandidates {
    final candidates = <String>[];

    if (_configuredBaseUrl.isNotEmpty) {
      candidates.add(_normalizeBaseUrl(_configuredBaseUrl));
    } else {
      candidates.add(_defaultBaseUrl);
    }

    if (_configuredFallbackBaseUrl.isNotEmpty) {
      final fallback = _normalizeBaseUrl(_configuredFallbackBaseUrl);
      if (!candidates.contains(fallback)) {
        candidates.add(fallback);
      }
    }

    return candidates;
  }

  void setToken(String? token) {
    _token = token;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) {
    return post('/auth/login', body: {'email': email, 'password': password});
  }

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
        'identity_validation_required': '1',
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
        'image_storage_score': selfieBiometric == null ? '0' : '100',
        'biometric_image_saved': selfieBiometric == null ? '0' : '1',
        'biometric_captured_at':
            selfieBiometric == null ? '' : DateTime.now().toIso8601String(),
        'biometric_provider': 'mobile_mlkit',
        'biometric_template_type': 'selfie-photo',
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

  Future<Map<String, dynamic>> registerCrew({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    String base = '',
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
        'base_airport': base,
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

  Future<Map<String, dynamic>> me() {
    return get('/auth/me', authenticated: true);
  }

  Future<void> logout() async {
    await post('/auth/logout', authenticated: true);
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
      '/client/flight-requests',
    ], authenticated: true);
    final raw =
        data['reservations'] ??
        data['reservas'] ??
        data['flight_requests'] ??
        data['requests'] ??
        data['data'];

    if (raw is Map && raw['data'] is List) {
      return _asListOfMaps(raw['data']);
    }

    return _asListOfMaps(raw);
  }

  Future<List<Map<String, dynamic>>> getClientFlightRequests() async {
    final data = await getFirstAvailable(const [
      '/client/flight-requests',
      '/cliente/solicitudes',
    ], authenticated: true);

    return _asListOfMaps(
      data['flight_requests'] ?? data['requests'] ?? data['data'],
    );
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

  Future<Map<String, dynamic>> getCrewPortal() {
    return getFirstAvailable(const [
      '/crew/portal',
      '/sobrecargo/portal',
      '/crew/dashboard',
      '/sobrecargo/dashboard',
    ], authenticated: true);
  }

  Future<Map<String, dynamic>> respondCrewAssignment({
    required String assignmentId,
    required String status,
    String reason = '',
  }) {
    return postFirstAvailable(
      [
        '/crew/assignments/$assignmentId/respond',
        '/sobrecargo/asignaciones/$assignmentId/responder',
        '/admin/crew-assignments/$assignmentId/respond',
      ],
      authenticated: true,
      body: {'status': status, if (reason.trim().isNotEmpty) 'reason': reason},
    );
  }

  Future<Map<String, dynamic>> createCrewAvailabilityBlock({
    required DateTime startsAt,
    required DateTime endsAt,
    required String reason,
  }) {
    return postFirstAvailable(
      const [
        '/crew/availability/blocks',
        '/sobrecargo/disponibilidad/bloqueos',
      ],
      authenticated: true,
      body: {
        'starts_at': startsAt.toIso8601String(),
        'ends_at': endsAt.toIso8601String(),
        'reason': reason,
      },
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

  Future<Map<String, dynamic>> getFirstAvailable(
    List<String> paths, {
    bool authenticated = false,
    Map<String, String>? query,
  }) async {
    ApiException? lastError;

    for (final path in paths) {
      try {
        return await get(path, authenticated: authenticated, query: query);
      } on ApiException catch (error) {
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
  }) async {
    ApiException? lastError;

    for (final path in paths) {
      try {
        return await post(path, body: body, authenticated: authenticated);
      } on ApiException catch (error) {
        lastError = error;
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
        lastError = error;
      }
    }

    throw lastError ??
        const ApiException('No fue posible completar la solicitud.');
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
  }) async {
    return _request(
      path,
      method: 'POST',
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
    Object? lastError;

    for (var index = 0; index < _backendCandidates.length; index++) {
      final candidate = _backendCandidates[index];

      try {
        final uri = _uri(candidate, path, null);
        final request =
            http.MultipartRequest('POST', uri)
              ..headers.addAll(_multipartHeaders(authenticated: authenticated))
              ..fields.addAll(fields);

        for (final entry in files.entries) {
          request.files.add(
            await http.MultipartFile.fromPath(entry.key, entry.value.path),
          );
        }

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        _activeBackendIndex = index;
        return _decode(response, candidate);
      } on ApiException catch (error) {
        lastError = error;
      } catch (error) {
        lastError = error;
      }
    }

    throw ApiException(
      'No fue posible conectar con el backend configurado.',
      cause: lastError,
    );
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    required String method,
    required bool authenticated,
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    Object? lastError;

    for (var index = 0; index < _backendCandidates.length; index++) {
      final candidate = _backendCandidates[index];

      try {
        final response = await _send(
          candidate,
          path,
          method: method,
          authenticated: authenticated,
          body: body,
          query: query,
        );
        _activeBackendIndex = index;
        return _decode(response, candidate);
      } on ApiException catch (error) {
        lastError = error;
      } catch (error) {
        lastError = error;
      }
    }

    throw ApiException(
      'No fue posible conectar con el backend configurado.',
      cause: lastError,
    );
  }

  Future<http.Response> _send(
    String candidate,
    String path, {
    required String method,
    required bool authenticated,
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = _uri(candidate, path, query);

    switch (method) {
      case 'POST':
        return http.post(
          uri,
          headers: _headers(authenticated: authenticated),
          body: jsonEncode(body ?? {}),
        );
      default:
        return http.get(uri, headers: _headers(authenticated: authenticated));
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

  Map<String, dynamic> _decode(
    http.Response response,
    String candidateBaseUrl,
  ) {
    final decoded =
        response.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        decoded['message']?.toString() ??
            'Error HTTP ${response.statusCode} en $candidateBaseUrl',
        statusCode: response.statusCode,
      );
    }

    if (decoded['success'] == false) {
      throw ApiException(decoded['message']?.toString() ?? 'Solicitud fallida');
    }

    return decoded;
  }

  List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? cause;

  const ApiException(this.message, {this.statusCode, this.cause});

  @override
  String toString() => message;
}
