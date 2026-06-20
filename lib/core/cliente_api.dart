import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  String? _token;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  String get baseUrl => _defaultBaseUrl;

  String get backendOrigin {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) return '';
    return uri.origin;
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
    bool biometricImageSaved = false,
    String biometricCapturedAt = '',
    String biometricProvider = 'aws_rekognition',
    String biometricTemplateType = 'selfie-photo',
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
    required Map<String, dynamic> contractPayload,
  }) {
    return postFirstAvailable(
      [
        '/cliente/reservas/$reservationId/contrato/docusign',
        '/client/reservations/$reservationId/contract/docusign',
        '/cliente/reservas/$reservationId/contrato/enviar',
        '/client/reservations/$reservationId/contract/send',
        '/contracts/send',
      ],
      authenticated: true,
      body: {
        'reservation_id': reservationId,
        'flight_request_id': reservationId,
        'booking_id': reservationId,
        ...contractPayload,
      },
    );
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
  }) {
    final body = {
      'flight_request_id': flightRequestId,
      'booking_id': flightRequestId,
      ...paymentPayload,
    };

    return postFirstAvailable(
      const ['/cliente/stripe/checkout/create', '/stripe/checkout/create'],
      authenticated: true,
      body: body,
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

    return writeFirstAvailable(
      const [
        '/cliente/stripe/payment-intent/confirm',
        '/stripe/payment-intent/confirm',
      ],
      authenticated: true,
      body: body,
    );
  }

  Future<Map<String, dynamic>> confirmClientPayment({
    required String reservationId,
    required Map<String, dynamic> paymentPayload,
  }) {
    return writeFirstAvailable(
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
    );
  }

  Future<Map<String, dynamic>> createClientAccessCheckout({
    required Map<String, dynamic> paymentPayload,
  }) {
    return postFirstAvailable(
      const ['/client/access-payment/create', '/cliente/access-payment/create'],
      authenticated: true,
      body: paymentPayload,
    );
  }

  Future<Map<String, dynamic>> getClientAccessPaymentSuccess({
    String? sessionId,
  }) {
    final query = <String, String>{
      if (sessionId != null && sessionId.trim().isNotEmpty)
        'session_id': sessionId.trim(),
    };

    return getFirstAvailable(
      const [
        '/client/access-payment/success',
        '/cliente/access-payment/success',
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
    return getFirstAvailable(
      const ['/sobrecargo/availability/statuses', '/crew/availability/statuses'],
      authenticated: true,
    );
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

  Future<Map<String, dynamic>> writeFirstAvailable(
    List<String> paths, {
    Map<String, dynamic>? body,
    bool authenticated = false,
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
          );
        } on ApiException catch (error) {
          if (!_shouldTryAlternative(error)) rethrow;
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
        if (!_shouldTryAlternative(error)) rethrow;
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
        if (!_shouldTryAlternative(error)) rethrow;
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
                : jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        decoded = const {};
      }
      throw ApiException(
        decoded['message']?.toString() ??
            'Error HTTP ${response.statusCode} en $baseUrl',
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
  }) async {
    return _request(
      path,
      method: 'POST',
      authenticated: authenticated,
      body: body,
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
      request.files.add(
        await http.MultipartFile.fromPath(entry.key, entry.value.path),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _decode(response, baseUrl);
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    required String method,
    required bool authenticated,
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final response = await _send(
      baseUrl,
      path,
      method: method,
      authenticated: authenticated,
      body: body,
      query: query,
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
  }) async {
    final uri = _uri(candidate, path, query);

    switch (method) {
      case 'POST':
        return http.post(
          uri,
          headers: _headers(authenticated: authenticated),
          body: jsonEncode(body ?? {}),
        );
      case 'PATCH':
        return http.patch(
          uri,
          headers: _headers(authenticated: authenticated),
          body: jsonEncode(body ?? {}),
        );
      case 'PUT':
        return http.put(
          uri,
          headers: _headers(authenticated: authenticated),
          body: jsonEncode(body ?? {}),
        );
      case 'DELETE':
        return http.delete(
          uri,
          headers: _headers(authenticated: authenticated),
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

  bool _shouldTryAlternative(ApiException error) {
    final status = error.statusCode ?? 0;
    return status == 0 || status == 404 || status == 405 || status >= 500;
  }

  Map<String, dynamic> _decode(
    http.Response response,
    String candidateBaseUrl,
  ) {
    final dynamic decodedRaw =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    final Map<String, dynamic> decoded =
        decodedRaw is Map<String, dynamic>
            ? decodedRaw
            : decodedRaw is Map
            ? Map<String, dynamic>.from(decodedRaw)
            : decodedRaw is List
            ? <String, dynamic>{'data': decodedRaw}
            : <String, dynamic>{'data': decodedRaw};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        decoded['message']?.toString() ??
            'Error HTTP ${response.statusCode} en $candidateBaseUrl',
        statusCode: response.statusCode,
        payload: decoded,
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

  @override
  String toString() => message;
}
