import 'dart:convert';

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
  static const String _defaultBaseUrl = 'https://uber-aviones.onrender.com/api/v1/';

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
