import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:red_sky/core/auth/secure_session_storage.dart';
import 'package:red_sky/core/cliente_api.dart';
import 'package:red_sky/models/aeropuerto.dart';
import 'package:red_sky/providers/proveedor_autenticacion.dart';
import 'package:red_sky/providers/proveedor_reservaciones.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final config = _AvailabilityAuditConfig.fromEnvironment();

  group('Real backend aircraft availability audit', () {
    testWidgets(
      'loads live airports and previews live quotes without Flutter hardcode',
      skip: !config.isReadFlowConfigured,
      timeout: const Timeout(Duration(minutes: 5)),
      (tester) async {
        final session = await _LiveBackendSession.createOrSignIn(
          config: config,
        );
        addTearDown(session.dispose);

        final provider = ReservationProvider(apiClient: session.api);
        addTearDown(provider.dispose);

        final airportsPayload = await session.api.getAirports();
        final airports =
            airportsPayload
                .map(
                  (json) => Airport.fromJson(Map<String, dynamic>.from(json)),
                )
                .where((airport) => _hasUsefulCode(airport))
                .toList();

        expect(
          airports.length,
          greaterThanOrEqualTo(2),
          reason:
              'El backend debe devolver al menos dos aeropuertos reales para cotizar.',
        );

        final route = await _resolveRouteAirports(
          airports: airports,
          config: config,
          api: session.api,
          passengers: config.passengers,
          departureDate: config.departureDate!,
        );
        provider.airports = airports;
        provider.passengers = config.passengers;
        provider.routes.first
          ..fromAirport = route.origin
          ..toAirport = route.destination
          ..startDate = config.departureDate!;

        final success = await provider.previewCurrentSelection();

        expect(
          success,
          isTrue,
          reason:
              'La cotizacion real no devolvio resultados con la ruta dinamica configurada.',
        );
        expect(provider.quoteMatches, isNotEmpty);

        for (final quote in provider.quoteMatches) {
          final availability = quote['is_available'];
          expect(
            availability == null || availability is bool,
            isTrue,
            reason:
                'is_available debe mantenerse como bool/null usando el JSON real del backend.',
          );
        }

        final selectable = _firstSelectableQuote(provider.quoteMatches);
        expect(
          selectable,
          isNotNull,
          reason:
              'No hubo ninguna aeronave seleccionable con disponibilidad true/null.',
        );
      },
    );

    testWidgets(
      'creates a real flight request from a live selectable quote when writes are enabled',
      skip: !config.isWriteFlowConfigured,
      timeout: const Timeout(Duration(minutes: 5)),
      (tester) async {
        final session = await _LiveBackendSession.createOrSignIn(
          config: config,
        );
        addTearDown(session.dispose);

        final provider = ReservationProvider(apiClient: session.api);
        addTearDown(provider.dispose);

        await _seedProviderFromBackend(provider, config, session.api);
        final previewOk = await provider.previewCurrentSelection();
        expect(previewOk, isTrue);

        final selectable = _firstSelectableQuote(provider.quoteMatches);
        expect(
          selectable,
          isNotNull,
          reason: 'La ruta dinamica no devolvio una aeronave seleccionable.',
        );

        final response = await provider.createFlightRequestForMatch(
          selectable!,
        );

        expect(
          provider.createdFlightRequestIdFromResponse(response),
          isNotEmpty,
          reason:
              'El backend creo la solicitud pero no devolvio un id utilizable.',
        );
      },
    );

    testWidgets(
      'executes central recovery for a seeded create-request availability conflict',
      skip: !config.isConflictCreateFlowConfigured,
      timeout: const Timeout(Duration(minutes: 5)),
      (tester) async {
        final session = await _LiveBackendSession.createOrSignIn(
          config: config,
        );
        addTearDown(session.dispose);

        final provider = ReservationProvider(apiClient: session.api);
        addTearDown(provider.dispose);

        await _seedProviderFromBackend(
          provider,
          config.forConflictRoute(),
          session.api,
        );
        final previewOk = await provider.previewCurrentSelection();
        expect(previewOk, isTrue);

        final quote = _firstSelectableQuote(provider.quoteMatches);
        final originalQuoteCount = provider.quoteMatches.length;
        expect(
          quote,
          isNotNull,
          reason:
              'La ruta de conflicto no devolvio una opcion seleccionable antes del 409.',
        );

        provider.setSelectedQuoteMatch(quote);
        final preservedDraft = provider.exportSearchDraft();
        final selectedQuote = quote!;

        try {
          await provider.createFlightRequestForMatch(selectedQuote);
          fail(
            'Se esperaba un conflicto real de backend con '
            '${config.expectedConflictCode}, pero la solicitud continuo.',
          );
        } on ApiException catch (error) {
          expect(error.isAircraftAvailabilityConflict, isTrue);
          expect(
            error.payload?['code'],
            config.expectedConflictCode,
            reason:
                'El backend respondio un codigo distinto al escenario real.',
          );

          provider.handleAircraftUnavailable({
            ...selectedQuote,
            ...?error.payload,
          });

          expect(provider.selectedAircraft, isNull);
          expect(provider.selectedQuoteMatch, isNull);
          expect(provider.quoteMatches.length, lessThan(originalQuoteCount));
          expect(provider.passengers, preservedDraft['passengers']);
          expect(
            provider.routes.first.fromAirport?.icao,
            _draftCode(preservedDraft, 'origin'),
          );
          expect(
            provider.routes.first.toAirport?.icao,
            _draftCode(preservedDraft, 'destination'),
          );
        }
      },
    );

    testWidgets(
      'validates a seeded contract availability conflict with the real backend',
      skip: !config.isContractConflictConfigured,
      timeout: const Timeout(Duration(minutes: 5)),
      (tester) async {
        final session = await _LiveBackendSession.createOrSignIn(
          config: config,
        );
        addTearDown(session.dispose);

        try {
          await session.api.sendClientContractForSignature(
            reservationId: config.contractReservationId,
            flightRequestId: config.contractFlightRequestId,
            contractPayload: {
              'id': config.contractEntityId,
              'reservation_id': config.contractReservationId,
              'flight_request_id': config.contractFlightRequestId,
              'return_context': 'integration_test',
              'regenerate': true,
            },
          );
          fail(
            'Se esperaba conflicto real de contrato con '
            '${config.expectedContractConflictCode}.',
          );
        } on ApiException catch (error) {
          expect(error.isAircraftAvailabilityConflict, isTrue);
          expect(error.payload?['code'], config.expectedContractConflictCode);
        }
      },
    );

    testWidgets(
      'allows only one real client to win a seeded concurrency scenario',
      skip: !config.isConcurrencyFlowConfigured,
      timeout: const Timeout(Duration(minutes: 5)),
      (tester) async {
        final sessionA = await _LiveBackendSession.createOrSignIn(
          config: config,
        );
        final sessionB = await _LiveBackendSession.createOrSignIn(
          config: config.forSecondClient(),
        );
        addTearDown(sessionA.dispose);
        addTearDown(sessionB.dispose);

        final providerA = ReservationProvider(apiClient: sessionA.api);
        final providerB = ReservationProvider(apiClient: sessionB.api);
        addTearDown(providerA.dispose);
        addTearDown(providerB.dispose);

        final conflictConfig = config.forConflictRoute();
        await _seedProviderFromBackend(providerA, conflictConfig, sessionA.api);
        await _seedProviderFromBackend(providerB, conflictConfig, sessionB.api);

        expect(await providerA.previewCurrentSelection(), isTrue);
        expect(await providerB.previewCurrentSelection(), isTrue);

        final quoteA = _firstSelectableQuote(providerA.quoteMatches);
        final quoteB = _firstSelectableQuote(providerB.quoteMatches);
        expect(quoteA, isNotNull);
        expect(quoteB, isNotNull);
        final firstClientQuote = quoteA!;
        final secondClientQuote = quoteB!;

        await providerA.createFlightRequestForMatch(firstClientQuote);

        try {
          await providerB.createFlightRequestForMatch(secondClientQuote);
          fail(
            'El segundo cliente no debio completar la misma disponibilidad '
            'en el escenario de concurrencia real.',
          );
        } on ApiException catch (error) {
          expect(error.isAircraftAvailabilityConflict, isTrue);
          expect(error.payload?['code'], config.expectedConflictCode);
          providerB.handleAircraftUnavailable({
            ...secondClientQuote,
            ...?error.payload,
          });
          expect(providerB.selectedQuoteMatch, isNull);
        }
      },
    );
  });
}

class _AvailabilityAuditConfig {
  const _AvailabilityAuditConfig({
    required this.baseUrl,
    required this.clientEmail,
    required this.clientPassword,
    required this.secondClientEmail,
    required this.secondClientPassword,
    required this.originIcao,
    required this.destinationIcao,
    required this.departureIso,
    required this.passengers,
    required this.allowWrites,
    required this.conflictOriginIcao,
    required this.conflictDestinationIcao,
    required this.conflictDepartureIso,
    required this.expectedConflictCode,
    required this.contractReservationId,
    required this.contractFlightRequestId,
    required this.contractEntityId,
    required this.expectedContractConflictCode,
  });

  final String baseUrl;
  final String clientEmail;
  final String clientPassword;
  final String secondClientEmail;
  final String secondClientPassword;
  final String originIcao;
  final String destinationIcao;
  final String departureIso;
  final int passengers;
  final bool allowWrites;
  final String conflictOriginIcao;
  final String conflictDestinationIcao;
  final String conflictDepartureIso;
  final String expectedConflictCode;
  final String contractReservationId;
  final String contractFlightRequestId;
  final String contractEntityId;
  final String expectedContractConflictCode;

  static _AvailabilityAuditConfig fromEnvironment() {
    return _AvailabilityAuditConfig(
      baseUrl: const String.fromEnvironment('AUDIT_API_BASE_URL'),
      clientEmail: const String.fromEnvironment('AUDIT_CLIENT_EMAIL'),
      clientPassword: const String.fromEnvironment('AUDIT_CLIENT_PASSWORD'),
      secondClientEmail: const String.fromEnvironment(
        'AUDIT_SECOND_CLIENT_EMAIL',
      ),
      secondClientPassword: const String.fromEnvironment(
        'AUDIT_SECOND_CLIENT_PASSWORD',
      ),
      originIcao: const String.fromEnvironment('AUDIT_ORIGIN_ICAO'),
      destinationIcao: const String.fromEnvironment('AUDIT_DESTINATION_ICAO'),
      departureIso: const String.fromEnvironment('AUDIT_DEPARTURE_ISO'),
      passengers:
          int.tryParse(
            const String.fromEnvironment('AUDIT_PASSENGERS', defaultValue: '1'),
          ) ??
          1,
      allowWrites: const String.fromEnvironment('AUDIT_ALLOW_WRITES') == 'true',
      conflictOriginIcao: const String.fromEnvironment(
        'AUDIT_CONFLICT_ORIGIN_ICAO',
      ),
      conflictDestinationIcao: const String.fromEnvironment(
        'AUDIT_CONFLICT_DESTINATION_ICAO',
      ),
      conflictDepartureIso: const String.fromEnvironment(
        'AUDIT_CONFLICT_DEPARTURE_ISO',
      ),
      expectedConflictCode: const String.fromEnvironment(
        'AUDIT_EXPECTED_CONFLICT_CODE',
      ),
      contractReservationId: const String.fromEnvironment(
        'AUDIT_CONTRACT_RESERVATION_ID',
      ),
      contractFlightRequestId: const String.fromEnvironment(
        'AUDIT_CONTRACT_FLIGHT_REQUEST_ID',
      ),
      contractEntityId: const String.fromEnvironment(
        'AUDIT_CONTRACT_ENTITY_ID',
      ),
      expectedContractConflictCode: const String.fromEnvironment(
        'AUDIT_EXPECTED_CONTRACT_CONFLICT_CODE',
      ),
    );
  }

  bool get isReadFlowConfigured => baseUrl.isNotEmpty && departureDate != null;

  bool get hasPrimaryCredentials =>
      clientEmail.isNotEmpty && clientPassword.isNotEmpty;

  bool get hasSecondCredentials =>
      secondClientEmail.isNotEmpty && secondClientPassword.isNotEmpty;

  bool get isWriteFlowConfigured =>
      isReadFlowConfigured && allowWrites && hasPrimaryCredentials;

  bool get isConflictCreateFlowConfigured =>
      isWriteFlowConfigured &&
      conflictOriginIcao.isNotEmpty &&
      conflictDestinationIcao.isNotEmpty &&
      conflictDepartureDate != null &&
      expectedConflictCode.isNotEmpty;

  bool get isContractConflictConfigured =>
      isReadFlowConfigured &&
      contractReservationId.isNotEmpty &&
      contractEntityId.isNotEmpty &&
      expectedContractConflictCode.isNotEmpty;

  bool get isConcurrencyFlowConfigured =>
      isConflictCreateFlowConfigured && hasSecondCredentials;

  DateTime? get departureDate => _parseDate(departureIso);

  DateTime? get conflictDepartureDate => _parseDate(conflictDepartureIso);

  _AvailabilityAuditConfig forConflictRoute() {
    return _AvailabilityAuditConfig(
      baseUrl: baseUrl,
      clientEmail: clientEmail,
      clientPassword: clientPassword,
      secondClientEmail: secondClientEmail,
      secondClientPassword: secondClientPassword,
      originIcao: conflictOriginIcao,
      destinationIcao: conflictDestinationIcao,
      departureIso: conflictDepartureIso,
      passengers: passengers,
      allowWrites: allowWrites,
      conflictOriginIcao: conflictOriginIcao,
      conflictDestinationIcao: conflictDestinationIcao,
      conflictDepartureIso: conflictDepartureIso,
      expectedConflictCode: expectedConflictCode,
      contractReservationId: contractReservationId,
      contractFlightRequestId: contractFlightRequestId,
      contractEntityId: contractEntityId,
      expectedContractConflictCode: expectedContractConflictCode,
    );
  }

  _AvailabilityAuditConfig forSecondClient() {
    return _AvailabilityAuditConfig(
      baseUrl: baseUrl,
      clientEmail: secondClientEmail,
      clientPassword: secondClientPassword,
      secondClientEmail: secondClientEmail,
      secondClientPassword: secondClientPassword,
      originIcao: originIcao,
      destinationIcao: destinationIcao,
      departureIso: departureIso,
      passengers: passengers,
      allowWrites: allowWrites,
      conflictOriginIcao: conflictOriginIcao,
      conflictDestinationIcao: conflictDestinationIcao,
      conflictDepartureIso: conflictDepartureIso,
      expectedConflictCode: expectedConflictCode,
      contractReservationId: contractReservationId,
      contractFlightRequestId: contractFlightRequestId,
      contractEntityId: contractEntityId,
      expectedContractConflictCode: expectedContractConflictCode,
    );
  }
}

class _LiveBackendSession {
  const _LiveBackendSession({
    required this.api,
    required this.auth,
    required this.storage,
  });

  final ApiClient api;
  final AuthProvider auth;
  final _MemorySessionStorage storage;

  static Future<_LiveBackendSession> createOrSignIn({
    required _AvailabilityAuditConfig config,
  }) async {
    final api = ApiClient.forTesting(
      baseUrl: config.baseUrl,
      httpClient: http.Client(),
    );
    final storage = _MemorySessionStorage();
    final auth = AuthProvider(api: api, sessionStorage: storage);

    final email = config.clientEmail.trim();
    final password = config.clientPassword.trim();
    if (email.isNotEmpty && password.isNotEmpty) {
      await auth.signIn(email: email, password: password);
    } else {
      final created = await _registerDynamicClient(auth);
      if (!created) {
        throw TestFailure(
          'No fue posible registrar un cliente temporal real. '
          'Error: ${auth.errorMessage ?? 'sin detalle'}',
        );
      }
    }

    if (!auth.isAuthenticated) {
      throw TestFailure(
        'No fue posible autenticar el cliente real para la auditoria. '
        'Error: ${auth.errorMessage ?? 'sin detalle'}',
      );
    }

    return _LiveBackendSession(api: api, auth: auth, storage: storage);
  }

  void dispose() {
    auth.dispose();
    api.setToken(null);
  }
}

class _ResolvedRoute {
  const _ResolvedRoute({required this.origin, required this.destination});

  final Airport origin;
  final Airport destination;
}

Future<void> _seedProviderFromBackend(
  ReservationProvider provider,
  _AvailabilityAuditConfig config,
  ApiClient api,
) async {
  final airportsPayload = await api.getAirports();
  final airports =
      airportsPayload
          .map((json) => Airport.fromJson(Map<String, dynamic>.from(json)))
          .where((airport) => _hasUsefulCode(airport))
          .toList();
  if (airports.length < 2) {
    throw TestFailure(
      'El backend no devolvio suficientes aeropuertos reales para la auditoria.',
    );
  }

  final route = await _resolveRouteAirports(
    airports: airports,
    config: config,
    api: api,
    passengers: config.passengers,
    departureDate: config.departureDate!,
  );
  provider.airports = airports;
  provider.passengers = config.passengers;
  provider.routes.first
    ..fromAirport = route.origin
    ..toAirport = route.destination
    ..startDate = config.departureDate!;
}

Future<_ResolvedRoute> _resolveRouteAirports({
  required List<Airport> airports,
  required _AvailabilityAuditConfig config,
  required ApiClient api,
  required int passengers,
  required DateTime departureDate,
}) async {
  if (config.originIcao.isNotEmpty && config.destinationIcao.isNotEmpty) {
    final origin = _findAirportByCode(airports, config.originIcao);
    final destination = _findAirportByCode(airports, config.destinationIcao);
    if (origin == null || destination == null) {
      throw TestFailure(
        'Los codigos configurados por entorno no existen en la respuesta real de /public/airports.',
      );
    }
    return _ResolvedRoute(origin: origin, destination: destination);
  }

  final candidates = airports.take(12).toList();
  for (final origin in candidates) {
    for (final destination in candidates) {
      if (_airportCode(origin) == _airportCode(destination)) continue;
      final hasQuotes = await _routeProducesQuotes(
        api: api,
        origin: origin,
        destination: destination,
        passengers: passengers,
        departureDate: departureDate,
      );
      if (hasQuotes) {
        return _ResolvedRoute(origin: origin, destination: destination);
      }
    }
  }

  throw TestFailure(
    'No se encontro una ruta cotizable de forma dinamica con los aeropuertos reales devueltos por el backend.',
  );
}

Map<String, dynamic>? _firstSelectableQuote(List<Map<String, dynamic>> quotes) {
  for (final quote in quotes) {
    if (quote['is_available'] != false) return quote;
  }
  return null;
}

Airport? _findAirportByCode(List<Airport> airports, String code) {
  final normalized = code.trim().toUpperCase();
  if (normalized.isEmpty) return null;
  for (final airport in airports) {
    if (_airportCode(airport) == normalized) return airport;
  }
  return null;
}

String _airportCode(Airport airport) =>
    (airport.icao ?? airport.iata ?? '').trim().toUpperCase();

bool _hasUsefulCode(Airport airport) => _airportCode(airport).isNotEmpty;

Future<bool> _registerDynamicClient(AuthProvider auth) async {
  final suffix = DateTime.now().microsecondsSinceEpoch.toString();
  final password = 'Audit${suffix}x!';
  return auth.registerClient(
    name: 'Cliente Audit $suffix',
    email: 'audit+$suffix@privateflights.test',
    phone: '+5255${suffix.substring(suffix.length - 8)}',
    password: password,
    passwordConfirmation: password,
    birthDate: '1990-01-01',
    nationality: 'Mexico',
    base: '',
    documentType: 'INE',
    documentNumber: '',
    identityValidationRequired: false,
  );
}

Future<bool> _routeProducesQuotes({
  required ApiClient api,
  required Airport origin,
  required Airport destination,
  required int passengers,
  required DateTime departureDate,
}) async {
  try {
    final payload = await api.previewClientQuotes(
      origin: _airportCode(origin),
      destination: _airportCode(destination),
      departure: departureDate,
      passengers: passengers,
      tripType: 'one_way',
    );
    final matches = _matchesFromPreviewPayload(payload);
    return matches.isNotEmpty;
  } on ApiException {
    return false;
  }
}

List<Map<String, dynamic>> _matchesFromPreviewPayload(
  Map<String, dynamic> payload,
) {
  final candidates = [
    payload['matches'],
    payload['matched_options'],
    payload['request_matches'],
    payload['results'],
    payload['options'],
    (payload['data'] is Map<String, dynamic>)
        ? (payload['data'] as Map<String, dynamic>)['matches']
        : null,
  ];
  for (final candidate in candidates) {
    if (candidate is! List) continue;
    return candidate
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
  return const <Map<String, dynamic>>[];
}

DateTime? _parseDate(String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty) return DateTime.now().add(const Duration(days: 7));
  return DateTime.tryParse(normalized);
}

String _draftCode(Map<String, dynamic> draft, String endpoint) {
  final routes = draft['routes'];
  if (routes is! List || routes.isEmpty) return '';
  final first = routes.first;
  if (first is! Map) return '';
  return (first[endpoint]?.toString() ?? '').trim().toUpperCase();
}

class _MemorySessionStorage implements SessionStorage {
  String? _token;

  @override
  Future<void> deleteToken() async {
    _token = null;
  }

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String value) async {
    _token = value;
  }
}
