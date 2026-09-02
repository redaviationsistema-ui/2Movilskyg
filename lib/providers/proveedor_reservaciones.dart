import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/billable_hours_formatter.dart';
import '../core/cliente_api.dart';
import '../core/quote_price_formatter.dart';
import '../core/config/app_environment.dart';
import '../core/client_workflow_status.dart';
import '../core/auth/session_cleanup_registry.dart';
import '../models/aeronave.dart';
import '../models/aeropuerto.dart';
import '../models/modelo_ruta.dart';
import '../services/servicio_memoria_local.dart';

enum QuotePreviewState {
  idle,
  loading,
  success,
  empty,
  validationError,
  serverError,
}

class ReservationProvider extends ChangeNotifier {
  ReservationProvider({ApiClient? apiClient, LocalCacheService? cacheService})
    : _api = apiClient ?? ApiClient.instance,
      _cacheService = cacheService ?? LocalCacheService() {
    SessionCleanupRegistry.register(clearSessionData);
  }
  static const bool _enableClientQuoteLogs = false;
  static const Set<String> _activeQuoteStatuses = {
    '',
    'active',
    'trial_active',
    'approved',
    'aprobada',
    'available',
    'disponible',
  };

  final ApiClient _api;
  final LocalCacheService _cacheService;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_MX',
    symbol: 'USD ',
    decimalDigits: 0,
  );

  Future<void> clearSessionData() async {
    flightRequests = [];
    quoteMatches = [];
    reservations = [];
    dashboardData = null;
    selectedQuoteMatch = null;
    _lastCreatedFlightRequestPayload = null;
    name = null;
    email = null;
    phone = null;
    fullName = '';
    workspaceMessage = null;
    quoteError = null;
    quoteEmptyMessage = null;
    quotePreviewState = QuotePreviewState.idle;
    lastWorkspaceSyncAt = null;
    await _cacheService.clearUserData();
    resetForm();
    notifyListeners();
  }

  @override
  void dispose() {
    SessionCleanupRegistry.unregister(clearSessionData);
    super.dispose();
  }

  String? flightType;
  String? aircraftType;

  String? paymentMethod;
  String? paymentNumber;
  String? bankName;
  String? clabe;
  String? cuenta;

  String language = 'ES';
  String routeType = 'NACIONAL';
  String bookingTripLabel = 'Solo ida';
  String selectedPriorityType = 'essential';
  String pets = '';
  String specialBaggage = '';
  String preference = '';
  bool conciergeRequested = false;

  bool isLoadingData = false;
  bool isLoadingWorkspace = false;
  bool isLoadingQuotePreview = false;
  bool isOnline = true;
  String? syncMessage;
  String? workspaceMessage;
  String? quoteError;
  String? quoteEmptyMessage;
  DateTime? lastSyncAt;
  DateTime? lastWorkspaceSyncAt;
  QuotePreviewState quotePreviewState = QuotePreviewState.idle;

  Aircraft? selectedAircraft;

  List<Aircraft> aircraftFleet = [];
  List<Map<String, dynamic>> flightRequests = [];
  List<Map<String, dynamic>> quoteMatches = [];
  Map<String, dynamic>? dashboardData;
  Map<String, dynamic>? selectedQuoteMatch;
  Map<String, dynamic>? _lastCreatedFlightRequestPayload;
  List<Map<String, dynamic>> _lastQuotedLegs = const [];
  int _lastQuotedPassengers = 1;
  String _lastQuotedTripTypeCode = 'one_way';
  String _lastQuotedTripTypeLabel = 'Ida';

  String? name;
  String? email;
  String? phone;
  String fullName = '';

  int passengers = 1;
  DateTime? startDate;
  DateTime? endDate;

  List<Map<String, dynamic>> reservations = [];

  List<Airport> airports = [];

  List<RouteModel> routes = [RouteModel()];

  bool get hasWorkspaceData =>
      dashboardData != null ||
      flightRequests.isNotEmpty ||
      aircraftFleet.isNotEmpty;

  bool get hasQuoteServerError =>
      quotePreviewState == QuotePreviewState.serverError;

  bool get hasQuoteValidationError =>
      quotePreviewState == QuotePreviewState.validationError;

  bool get hasQuoteEmptyResult => quotePreviewState == QuotePreviewState.empty;

  List<Map<String, dynamic>> get quoteDisplayLegs {
    final currentLegs = _normalizedBackendLegs();
    if (currentLegs.isNotEmpty) {
      return currentLegs.map((leg) => Map<String, dynamic>.from(leg)).toList();
    }
    return _lastQuotedLegs
        .map((leg) => Map<String, dynamic>.from(leg))
        .toList();
  }

  int get quoteDisplayPassengers {
    if (_completeQuoteRoutes().isNotEmpty) {
      return passengers;
    }
    return _lastQuotedPassengers;
  }

  static const Map<String, String> priorityLabels = {
    'empty_leg': 'Empty Leg',
    'essential': 'Essential',
    'business': 'Business',
    'elite': 'Elite',
  };

  static String _normalizeFlightBaseSource(dynamic source) {
    final normalized = source?.toString().trim().toLowerCase() ?? '';
    return normalized == 'billable_hours' || normalized == 'pricing_trip_hours'
        ? normalized
        : 'pricing_trip_hours';
  }

  String get selectedPriorityLabel =>
      priorityLabels[selectedPriorityType] ?? 'Essential';

  void setLanguage(String value) {
    language = value;
    notifyListeners();
  }

  Future<bool> checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchReservationsRemote() async {
    if (!_api.hasToken) return [];

    try {
      final response = await _api.getReservations();

      return response
          .map<Map<String, dynamic>>(
            (r) => {
              'aircraft_id':
                  r['assigned_aircraft_id'] ??
                  r['aircraft_id'] ??
                  r['aircraft']?['id'],
              'start_datetime':
                  r['start_datetime'] ?? r['departure_datetime'] ?? r['date'],
              'end_datetime':
                  r['end_datetime'] ??
                  r['arrival_datetime'] ??
                  r['departure_datetime'] ??
                  r['date'],
              'status': r['status'] ?? r['workflow_status'],
            },
          )
          .where(
            (row) =>
                row['aircraft_id'] != null &&
                row['start_datetime'] != null &&
                row['end_datetime'] != null,
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> _mapReservationRows(
    List<Map<String, dynamic>> rows,
  ) {
    return rows
        .map(
          (r) => {
            'aircraftId': r['aircraft_id'],
            'startDatetime': DateTime.parse(r['start_datetime'] as String),
            'endDatetime': DateTime.parse(r['end_datetime'] as String),
            'status': r['status'],
          },
        )
        .toList();
  }

  Map<String, dynamic> _normalizeAirport(dynamic raw) {
    final json = Map<String, dynamic>.from(raw as Map);

    return {
      'id':
          json['id'] ??
          json['airport_id'] ??
          json['aeropuerto_id'] ??
          json['ID'] ??
          json['airportId'],
      'name':
          json['AEROPUERTO'] ??
          json['name'] ??
          json['airport'] ??
          json['nombre'] ??
          '',
      'city': json['CIUDAD'] ?? json['city'] ?? json['municipality'] ?? '',
      'state': json['ESTADO'] ?? json['state'] ?? json['region'],
      'lat': _toDouble(json['LATITUDE'] ?? json['lat']),
      'lng': _toDouble(json['LONGITUDE'] ?? json['lng']),
      'iata': json['IATA'] ?? json['iata'] ?? json['gps_code'],
      'icao': json['ICAO'] ?? json['icao'] ?? json['ident'] ?? json['gps_code'],
      'country':
          json['PAIS'] ??
          json['country'] ??
          json['COUNTRY'] ??
          json['iso_country'] ??
          'MEXICO',
    };
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> loadCachedData({String? fallbackReason}) async {
    final cachedAirports = await _cacheService.getCachedAirports();
    final cachedAircraft = await _cacheService.getCachedAircraft();
    final cachedReservations = await _cacheService.getCachedReservations();
    final cachedSyncAt = await _cacheService.getMetadata('last_sync_at');

    airports =
        cachedAirports
            .map((row) => Airport.fromJson(Map<String, dynamic>.from(row)))
            .toList();
    aircraftFleet =
        cachedAircraft
            .map((row) => Aircraft.fromJson(Map<String, dynamic>.from(row)))
            .toList();
    reservations = _mapReservationRows(
      cachedReservations.map((row) => Map<String, dynamic>.from(row)).toList(),
    );

    lastSyncAt = cachedSyncAt == null ? null : DateTime.tryParse(cachedSyncAt);
    isOnline = false;

    if (airports.isEmpty && aircraftFleet.isEmpty) {
      syncMessage =
          fallbackReason == null
              ? 'No hay datos locales guardados en el telefono.'
              : 'Sin conexion y sin datos locales guardados.';
    } else {
      final syncText =
          lastSyncAt == null
              ? 'sin fecha previa'
              : 'ultima sincronizacion ${lastSyncAt!.day.toString().padLeft(2, '0')}/${lastSyncAt!.month.toString().padLeft(2, '0')}/${lastSyncAt!.year} ${lastSyncAt!.hour.toString().padLeft(2, '0')}:${lastSyncAt!.minute.toString().padLeft(2, '0')}';

      syncMessage =
          'Modo offline: se cargaron ${airports.length} aeropuertos, ${aircraftFleet.length} aeronaves y ${reservations.length} reservas desde la base local ($syncText).';
    }
  }

  Future<void> loadInitialData() async {
    final syncStopwatch = Stopwatch()..start();
    isLoadingData = true;
    syncMessage = 'Sincronizando informacion con el servidor...';
    notifyListeners();

    try {
      final hasInternet = await checkInternetConnection();
      if (!hasInternet) {
        await loadCachedData(fallbackReason: 'no_internet');
        return;
      }

      final results = await Future.wait<dynamic>([
        _api.getAirports(),
        _api.getAircraftPreview(),
        _fetchReservationsRemote(),
      ]);

      final normalizedAirports = (results[0] as List<Map<String, dynamic>>).map(
        _normalizeAirport,
      );

      airports = normalizedAirports.map(Airport.fromJson).toList();

      final aircraftResponse = results[1] as List<Map<String, dynamic>>;
      aircraftFleet =
          aircraftResponse
              .map((json) => Aircraft.fromJson(Map<String, dynamic>.from(json)))
              .toList();

      final remoteReservations = results[2] as List<Map<String, dynamic>>;
      reservations = _mapReservationRows(remoteReservations);

      await _cacheService.cacheAirports(
        airports.map((airport) => airport.toCacheMap()).toList(),
      );
      await _cacheService.cacheAircraft(
        aircraftFleet.map((aircraft) => aircraft.toCacheMap()).toList(),
      );
      await _cacheService.cacheReservations(remoteReservations);

      final now = DateTime.now();
      await _cacheService.setMetadata('last_sync_at', now.toIso8601String());

      lastSyncAt = now;
      isOnline = true;
      final elapsedSeconds = (syncStopwatch.elapsedMilliseconds / 1000)
          .toStringAsFixed(1);
      syncMessage =
          'Sincronizacion completada en ${elapsedSeconds}s: ${airports.length} aeropuertos, ${aircraftFleet.length} aeronaves y ${reservations.length} reservas guardadas en el telefono.';
    } catch (e) {
      debugPrint('ERROR LOADING DATA: $e');
      await loadCachedData(fallbackReason: e.toString());
    } finally {
      isLoadingData = false;
      notifyListeners();
    }
  }

  Future<void> loadClientWorkspaceData({bool force = false}) async {
    if (isLoadingWorkspace) return;
    if (!force && hasWorkspaceData && lastWorkspaceSyncAt != null) return;

    final workspaceStopwatch = Stopwatch()..start();
    isLoadingWorkspace = true;
    workspaceMessage = 'Actualizando cabina...';
    notifyListeners();

    try {
      await loadInitialData();

      if (!_api.hasToken) {
        workspaceMessage = 'Inicia sesion para ver informacion privada.';
        return;
      }

      final originHint = _backendAirportCode(routes.first.fromAirport);
      final departureHint =
          routes.isEmpty ? startDate : routes.first.startDate ?? startDate;
      final results = await Future.wait<dynamic>([
        _api.getClientDashboard(),
        _api.getClientFlightRequests(),
        _api.getReservations(),
        departureHint == null
            ? Future.value(const <Map<String, dynamic>>[])
            : _api.getClientAircraft(
              origin: originHint,
              passengers: passengers,
              departure: departureHint,
            ),
      ]);

      final dashboardResponse = results[0] as Map<String, dynamic>;
      final requests = results[1] as List<Map<String, dynamic>>;
      final historyReservations = results[2] as List<Map<String, dynamic>>;
      final liveAircraft = results[3] as List<Map<String, dynamic>>;

      dashboardData = Map<String, dynamic>.from(dashboardResponse);
      flightRequests = _mergeFlightHistoryRows([
        ...historyReservations,
        ...requests,
      ]);

      if (liveAircraft.isNotEmpty) {
        aircraftFleet =
            liveAircraft
                .map(
                  (json) => Aircraft.fromJson(Map<String, dynamic>.from(json)),
                )
                .toList();
      }

      lastWorkspaceSyncAt = DateTime.now();
      final elapsedSeconds = (workspaceStopwatch.elapsedMilliseconds / 1000)
          .toStringAsFixed(1);
      workspaceMessage =
          'Cabina sincronizada en ${elapsedSeconds}s con ${flightRequests.length} solicitudes y ${aircraftFleet.length} aeronaves.';
    } catch (error) {
      workspaceMessage = 'No fue posible sincronizar la cabina: $error';
    } finally {
      isLoadingWorkspace = false;
      notifyListeners();
    }
  }

  Future<bool> previewCurrentSelection() async {
    final previousMatches = List<Map<String, dynamic>>.from(quoteMatches);
    final previousSelectedQuote =
        selectedQuoteMatch == null
            ? null
            : Map<String, dynamic>.from(selectedQuoteMatch!);
    quoteError = null;
    quoteEmptyMessage = null;
    isLoadingQuotePreview = true;
    quotePreviewState = QuotePreviewState.loading;
    notifyListeners();

    try {
      final validationError = _quoteValidationMessage();
      if (validationError != null) {
        quoteError = validationError;
        quotePreviewState = QuotePreviewState.validationError;
        return false;
      }

      final segmentCount = _completeQuoteRoutes().length;
      final previewPayload = _buildBackendFlightRequestPayload();
      _rememberQuotedSearch(previewPayload);
      assert(() {
        debugPrint('========================================');
        debugPrint('[QUOTE REQUEST][MOBILE]');
        debugPrint('method = POST');
        debugPrint('baseUrl = ${_api.baseUrl}');
        debugPrint('endpoint = ${_api.baseUrl}/client/quotes/preview');
        debugPrint('environment = ${AppEnvironment.current.label}');
        debugPrint(
          'origin_airport_id = ${previewPayload['origin_airport_id'] ?? ''}',
        );
        debugPrint(
          'origin_icao = ${previewPayload['origin_icao'] ?? previewPayload['origin'] ?? ''}',
        );
        debugPrint(
          'destination_airport_id = ${previewPayload['destination_airport_id'] ?? ''}',
        );
        debugPrint(
          'destination_icao = ${previewPayload['destination_icao'] ?? previewPayload['destination'] ?? ''}',
        );
        debugPrint('trip_type = ${previewPayload['trip_type'] ?? ''}');
        debugPrint('return_date = ${previewPayload['return_date'] ?? ''}');
        debugPrint('aircraft_id = ${previewPayload['aircraft_id'] ?? ''}');
        debugPrint(
          'passenger_count = ${previewPayload['passenger_count'] ?? previewPayload['passengers'] ?? ''}',
        );
        debugPrint(
          'flight_time_model = ${previewPayload['flight_time_model'] ?? ''}',
        );
        debugPrint(
          'include_operational_time = ${previewPayload['include_operational_time'] ?? ''}',
        );
        debugPrint(
          'route_signature = ${previewPayload['route_signature'] ?? ''}',
        );
        debugPrint('headers = Authorization, Content-Type: application/json');
        debugPrint('========================================');
        return true;
      }());
      final response = await _api.previewClientQuotesPayload(previewPayload);

      quoteMatches = _normalizeMatches(response, segmentCount: segmentCount);
      final primaryRoute = _completeQuoteRoutes().first;
      quoteMatches = _filterMatchesForItinerary(
        quoteMatches,
        primaryRoute.fromAirport,
      );

      if (_enableClientQuoteLogs) {
        for (final match in quoteMatches) {
          debugPrint(
            '[client-quote][panel] avion=${match['aircraft'] ?? match['aircraft_name'] ?? match['model']} total=${_quoteOfficialTotalValue(match)} tiempo=${match['time']}',
          );
        }
      }

      selectedQuoteMatch = _pickSelectedQuoteMatch(quoteMatches);

      if (quoteMatches.isEmpty) {
        quotePreviewState = QuotePreviewState.empty;
        quoteEmptyMessage =
            'No encontramos aeronaves disponibles en el aeropuerto de origen ni en bases cercanas dentro del radio operativo.';
        return true;
      }

      quotePreviewState = QuotePreviewState.success;
      return true;
    } on ApiException catch (error) {
      if (previousMatches.isNotEmpty) {
        quoteMatches = previousMatches;
        selectedQuoteMatch = previousSelectedQuote;
      }
      quoteError = _quotePreviewErrorMessage(error);
      quotePreviewState = QuotePreviewState.serverError;
      return false;
    } on TimeoutException {
      if (previousMatches.isNotEmpty) {
        quoteMatches = previousMatches;
        selectedQuoteMatch = previousSelectedQuote;
      }
      quoteError =
          'El servidor tardó demasiado en responder. Intenta nuevamente en unos momentos.';
      quotePreviewState = QuotePreviewState.serverError;
      return false;
    } on SocketException {
      if (previousMatches.isNotEmpty) {
        quoteMatches = previousMatches;
        selectedQuoteMatch = previousSelectedQuote;
      }
      quoteError =
          'No fue posible conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.';
      quotePreviewState = QuotePreviewState.serverError;
      return false;
    } catch (error) {
      if (previousMatches.isNotEmpty) {
        quoteMatches = previousMatches;
        selectedQuoteMatch = previousSelectedQuote;
      }
      quoteError = 'No fue posible obtener una cotizacion real: $error';
      quotePreviewState = QuotePreviewState.serverError;
      return false;
    } finally {
      isLoadingQuotePreview = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createFlightRequestForMatch(
    Map<String, dynamic> quote,
  ) async {
    final validationError = _quoteValidationMessage();
    if (validationError != null && _lastQuotedLegs.isEmpty) {
      throw StateError(validationError);
    }

    final payload = _buildBackendFlightRequestPayload(
      quote: quote,
      allowSnapshotFallback: validationError != null,
    );
    _lastCreatedFlightRequestPayload = payload;

    final response = await _api.createFlightRequestPayload(payload);
    rememberCreatedFlightRequest(response);

    return response;
  }

  String? createdFlightRequestIdFromResponse(Map<String, dynamic> response) {
    return _resolveEntityId(_createdFlightRequestRecord(response)) ??
        _resolveEntityId(response['flight_request']) ??
        _resolveEntityId(_nestedMap(response['data'])['flight_request']) ??
        _resolveEntityId(response['reservation']) ??
        _resolveEntityId(response['trip']) ??
        _resolveEntityId(response['data']) ??
        _resolveEntityId(response);
  }

  void rememberCreatedFlightRequest(Map<String, dynamic> response) {
    final createdRecord = _createdFlightRequestRecord(response);
    final createdId =
        _resolveEntityId(createdRecord) ??
        createdFlightRequestIdFromResponse(response);

    if (createdRecord == null && createdId == null) return;

    final payload =
        _lastCreatedFlightRequestPayload ?? const <String, dynamic>{};
    final explicitWorkflow =
        _firstText(createdRecord ?? const <String, dynamic>{}, const [
          'workflow_status',
          'workflow',
          'status',
        ]) ??
        _firstText(response, const ['workflow_status', 'workflow', 'status']) ??
        '';
    final request = <String, dynamic>{
      ...payload,
      if (createdRecord != null) ...createdRecord,
      if (createdId != null) 'id': createdId,
      if (createdId != null) 'flight_request_id': createdId,
      if (explicitWorkflow.isEmpty) 'status': 'reserved',
      if (explicitWorkflow.isEmpty) 'workflow_status': 'reserva solicitada',
      if (explicitWorkflow.isEmpty) 'booking_status': 'reserved',
      if (explicitWorkflow.isEmpty) 'next_action': 'sent_to_provider',
      'summary_only': false,
    };
    final requestId = _resolveEntityId(request);
    if (requestId == null || requestId.isEmpty) return;

    flightRequests = [
      request,
      ...flightRequests.where((item) {
        final itemId = _resolveEntityId(item);
        return itemId == null || itemId != requestId;
      }),
    ];
    notifyListeners();
  }

  void markPaymentPending({
    required String flightRequestId,
    String reservationId = '',
    String paymentMethod = 'stripe_checkout',
    String checkoutSessionId = '',
  }) {
    if (flightRequestId.trim().isEmpty && reservationId.trim().isEmpty) return;

    final pendingAt = DateTime.now().toIso8601String();
    final normalizedFlightRequestId = flightRequestId.trim();
    final normalizedReservationId = reservationId.trim();

    flightRequests =
        flightRequests.map((row) {
          final item = Map<String, dynamic>.from(row);
          final itemId = _resolveEntityId(item) ?? '';
          final itemFlightRequestId =
              _resolveEntityId(item['flight_request_id']) ??
              _resolveEntityId(_nestedMap(item['flight_request'])['id']) ??
              '';
          final itemReservationId =
              _resolveEntityId(item['reservation_id']) ??
              _resolveEntityId(_nestedMap(item['reservation'])['id']) ??
              '';

          final matches =
              (normalizedFlightRequestId.isNotEmpty &&
                  (itemId == normalizedFlightRequestId ||
                      itemFlightRequestId == normalizedFlightRequestId)) ||
              (normalizedReservationId.isNotEmpty &&
                  itemReservationId == normalizedReservationId);

          if (!matches) return item;

          final reservation = _nestedMap(item['reservation']);
          final paymentOrder = _nestedMap(item['payment_order']);
          final payments = _paymentsFromRow(item);

          return {
            ...item,
            if (normalizedFlightRequestId.isNotEmpty)
              'flight_request_id': normalizedFlightRequestId,
            if (normalizedReservationId.isNotEmpty)
              'reservation_id': normalizedReservationId,
            'payment_method': paymentMethod,
            'payment_status': 'pending',
            'payment_completed': false,
            'is_paid': false,
            'status': 'payment_pending',
            'booking_status': 'pending_payment',
            'workflow_status': 'pago pendiente',
            if (checkoutSessionId.isNotEmpty)
              'checkout_session_id': checkoutSessionId,
            if (checkoutSessionId.isNotEmpty)
              'stripe_checkout_session_id': checkoutSessionId,
            'updated_at': pendingAt,
            'payment_order': {
              ...paymentOrder,
              'status': 'pending',
              if (checkoutSessionId.isNotEmpty)
                'checkout_session_id': checkoutSessionId,
              if (paymentMethod.isNotEmpty) 'payment_method': paymentMethod,
            },
            'payments': [
              {
                'status': 'pending',
                'created_at': pendingAt,
                if (checkoutSessionId.isNotEmpty)
                  'checkout_session_id': checkoutSessionId,
                if (paymentMethod.isNotEmpty) 'payment_method': paymentMethod,
              },
              ...payments,
            ],
            'reservation': {
              ...reservation,
              if (normalizedReservationId.isNotEmpty)
                'id': normalizedReservationId,
              'status': 'pending_payment',
              'booking_status': 'pending_payment',
              'payment_status': 'pending',
              if (checkoutSessionId.isNotEmpty)
                'checkout_session_id': checkoutSessionId,
              if (checkoutSessionId.isNotEmpty)
                'stripe_checkout_session_id': checkoutSessionId,
            },
          };
        }).toList();

    notifyListeners();
  }

  Map<String, dynamic> _buildBackendFlightRequestPayload({
    Map<String, dynamic>? quote,
    bool allowSnapshotFallback = false,
  }) {
    final normalizedLegs = _normalizedBackendLegs(
      allowSnapshotFallback: allowSnapshotFallback,
    );
    final usingSnapshot =
        allowSnapshotFallback &&
        normalizedLegs.isNotEmpty &&
        _completeQuoteRoutes().isEmpty &&
        _lastQuotedLegs.isNotEmpty;
    final firstLeg = normalizedLegs.isNotEmpty ? normalizedLegs.first : null;
    final lastLeg = normalizedLegs.isNotEmpty ? normalizedLegs.last : null;
    final explicitTripType =
        usingSnapshot ? _lastQuotedTripTypeCode : currentTripTypeCode;
    final inferredClosedRoute =
        normalizedLegs.length > 1 &&
        (firstLeg?['origin']?.toString().trim().toUpperCase() ?? '') ==
            (lastLeg?['destination']?.toString().trim().toUpperCase() ?? '');
    final tripType =
        explicitTripType != 'one_way'
            ? explicitTripType
            : normalizedLegs.length > 2 ||
                (normalizedLegs.length > 1 && !inferredClosedRoute)
            ? 'multi_leg'
            : normalizedLegs.length == 2 && inferredClosedRoute
            ? 'round_trip'
            : 'one_way';
    final shouldCloseRoute =
        tripType == 'multi_leg' &&
        (inferredClosedRoute || normalizedLegs.length > 1);
    final departureDatetime =
        firstLeg?['departure_datetime']?.toString().trim() ?? '';
    final String? returnDatetime =
        inferredClosedRoute
            ? (lastLeg?['departure_datetime']?.toString().trim())
            : null;
    final departureDate = firstLeg?['date']?.toString().trim() ?? '';
    final departureTime = firstLeg?['time']?.toString().trim() ?? '';
    final returnDate =
        inferredClosedRoute ? (lastLeg?['date']?.toString().trim() ?? '') : '';
    final selectedAircraftModel =
        (quote?['aircraft'] ??
                quote?['aircraft_name'] ??
                quote?['model'] ??
                quote?['registration'] ??
                preference)
            ?.toString()
            .trim() ??
        '';
    final priorityCode = selectedPriorityType.trim();
    final pricingBreakdown =
        quote == null
            ? const <String, dynamic>{}
            : mergeBackendPricingSources(quote);
    final finalBillableHours =
        quote == null ? null : extractBackendBillableHours(quote);
    final totalBillableHours =
        quote == null ? null : extractBackendTotalBillableHours(quote);
    final routeBillableHours =
        quote == null ? null : extractBackendRouteBillableHours(quote);
    final total = _resolveOfficialQuoteTotal(
      quote ?? const <String, dynamic>{},
    );
    final basePrice = _asNumber(
      quote?['base_price'] ??
          quote?['flight_base'] ??
          pricingBreakdown['base_price'] ??
          pricingBreakdown['client_flight_cost'],
    );
    final priorityMultiplier = _asNumber(
      quote?['priority_multiplier'] ??
          quote?['service_multiplier'] ??
          pricingBreakdown['priority_multiplier'],
      1,
    );
    final priorityPrice = _asNumber(
      quote?['priority_price'] ??
          pricingBreakdown['priority_price'] ??
          pricingBreakdown['markup'],
    );
    final subtotal = _asNumber(
      quote?['subtotal'] ??
          quote?['subtotal_before_multipliers'] ??
          pricingBreakdown['subtotal'] ??
          pricingBreakdown['subtotal_before_multipliers'] ??
          basePrice,
    );
    final days = _itineraryDays(normalizedLegs);
    final payload = <String, dynamic>{
      'origin': firstLeg?['origin'] ?? '',
      'base_airport': firstLeg?['origin'] ?? '',
      'destination': firstLeg?['destination'] ?? '',
      'departure_datetime': departureDatetime,
      'passengers': usingSnapshot ? _lastQuotedPassengers : passengers,
      'trip_type': tripType,
      'trip_label':
          usingSnapshot ? _lastQuotedTripTypeLabel : currentTripTypeLabel,
      'return_to_origin':
          tripType == 'multi_leg' ? shouldCloseRoute : inferredClosedRoute,
      'return_to_start':
          tripType == 'multi_leg' ? shouldCloseRoute : inferredClosedRoute,
      'close_route':
          tripType == 'multi_leg' ? shouldCloseRoute : inferredClosedRoute,
      'open_route': tripType == 'multi_leg' ? !shouldCloseRoute : false,
      'priority_type': priorityCode,
      'priority_multiplier': priorityMultiplier,
      'time_display_mode': 'operational',
      'billing_hours_mode': quote?['billing_hours_mode'] ?? 'operational',
      'flight_base_source': _normalizeFlightBaseSource(
        quote?['flight_base_source'],
      ),
      'include_repositioning_in_billed_hours':
          quote?['include_repositioning_in_billed_hours'] ?? true,
      'include_return_to_base_in_billed_hours':
          quote?['include_return_to_base_in_billed_hours'] ?? true,
      'include_overnight_in_billed_hours':
          quote?['include_overnight_in_billed_hours'] ?? false,
      'legs': normalizedLegs,
      'requirements':
          normalizedLegs.length > 1
              ? (inferredClosedRoute && tripType == 'multi_leg'
                  ? normalizedLegs.sublist(1, normalizedLegs.length - 1)
                  : normalizedLegs.sublist(1))
              : [],
    };

    _putIfMeaningful(
      payload,
      'origin_airport_id',
      firstLeg?['origin_airport_id'],
    );
    _putIfMeaningful(payload, 'origin_icao', firstLeg?['origin_icao']);
    _putIfMeaningful(payload, 'origin_iata', firstLeg?['origin_iata']);
    _putIfMeaningful(payload, 'origin_airport', firstLeg?['origin_airport']);
    _putIfMeaningful(
      payload,
      'destination_airport_id',
      firstLeg?['destination_airport_id'],
    );
    _putIfMeaningful(
      payload,
      'destination_icao',
      firstLeg?['destination_icao'],
    );
    _putIfMeaningful(
      payload,
      'destination_iata',
      firstLeg?['destination_iata'],
    );
    _putIfMeaningful(
      payload,
      'destination_airport',
      firstLeg?['destination_airport'],
    );
    _putIfMeaningful(payload, 'departure_date', departureDate);
    _putIfMeaningful(payload, 'departure_time', departureTime);
    _putIfMeaningful(payload, 'start_date', departureDate);
    _putIfMeaningful(payload, 'start_time', departureTime);
    _putIfMeaningful(payload, 'start_datetime', departureDatetime);
    _putIfMeaningful(payload, 'return_date', returnDate);
    _putIfMeaningful(payload, 'return_datetime', returnDatetime);
    _putIfMeaningful(
      payload,
      'aircraft_type',
      selectedAircraftModel.isNotEmpty
          ? selectedAircraftModel
          : (flightType ?? aircraftType),
    );
    _putIfMeaningful(payload, 'aircraft_model', selectedAircraftModel);
    _putIfMeaningful(payload, 'assigned_aircraft_model', selectedAircraftModel);
    _putIfMeaningful(payload, 'aircraft_name', selectedAircraftModel);
    _putIfMeaningful(payload, 'aircraft_id', quote?['aircraft_id']);
    _putIfMeaningful(payload, 'provider_id', quote?['provider_id']);
    _putIfMeaningful(
      payload,
      'match_id',
      quote?['match_id'] ?? quote?['matched_option_id'] ?? quote?['id'],
    );
    _putIfMeaningful(
      payload,
      'matched_option_id',
      quote?['matched_option_id'] ?? quote?['match_id'] ?? quote?['id'],
    );
    _putIfMeaningful(payload, 'flight_package', priorityCode);
    _putIfMeaningful(payload, 'service_tier', priorityCode);
    _putIfMeaningful(payload, 'source_database', quote?['source_database']);
    _putIfMeaningful(payload, 'source_table', quote?['source_table']);
    _putIfMeaningful(payload, 'pets', pets.trim());
    _putIfMeaningful(payload, 'special_baggage', specialBaggage.trim());
    _putIfMeaningful(
      payload,
      'preference',
      preference.trim().isEmpty ? selectedAircraftModel : preference.trim(),
    );
    _putIfMeaningful(payload, 'overnight_nights', days == 0 ? null : days);
    _putIfMeaningful(payload, 'days', days);
    _putIfMeaningful(
      payload,
      'notes',
      [
        usingSnapshot ? _lastQuotedTripTypeLabel : currentTripTypeLabel,
        priorityCode,
        pets.trim() == 'Si' ? 'Mascotas a bordo' : '',
        specialBaggage.trim(),
        'Noches $days',
      ].where((item) => _hasMeaningfulValue(item)).join(' · '),
    );

    if (quote != null) {
      _putIfMeaningful(
        payload,
        'priority_price',
        priorityPrice == 0 ? null : priorityPrice,
      );
      _putIfMeaningful(
        payload,
        'base_price',
        basePrice == 0 ? null : basePrice,
      );
      _putIfMeaningful(payload, 'subtotal', subtotal == 0 ? null : subtotal);
      _putIfMeaningful(payload, 'estimated_total', total == 0 ? null : total);
      _putIfMeaningful(payload, 'total', total == 0 ? null : total);
      _putIfMeaningful(payload, 'final_price', total == 0 ? null : total);
      _putIfMeaningful(
        payload,
        'selected_card_price',
        total == 0 ? null : total,
      );
      _putIfMeaningful(
        payload,
        'operational_fee',
        _asNumber(
                  quote['operational_fee'] ??
                      pricingBreakdown['operational_fee'],
                ) ==
                0
            ? null
            : _asNumber(
              quote['operational_fee'] ?? pricingBreakdown['operational_fee'],
            ),
      );
      _putIfMeaningful(
        payload,
        'pricing_context',
        pricingBreakdown.isEmpty ? null : pricingBreakdown,
      );
      _putIfMeaningful(
        payload,
        'pricing_formula_version',
        pricingBreakdown['pricing_formula_version'] ??
            quote['pricing_formula_version'],
      );
      _putIfMeaningful(
        payload,
        'commercial_margin',
        pricingBreakdown['commercial_margin'] ?? quote['commercial_margin'],
      );
      _putIfMeaningful(
        payload,
        'priority_factor',
        pricingBreakdown['priority_factor'] ?? quote['priority_factor'],
      );
      _putIfMeaningful(payload, 'billable_hours', totalBillableHours);
      _putIfMeaningful(payload, 'final_billable_hours', finalBillableHours);
      _putIfMeaningful(payload, 'route_billable_hours', routeBillableHours);
      _putIfMeaningful(
        payload,
        'real_flight_hours',
        pricingBreakdown['real_flight_hours'] ?? quote['real_flight_hours'],
      );
      _putIfMeaningful(
        payload,
        'minimum_hours',
        pricingBreakdown['minimum_hours'] ?? quote['minimum_hours'],
      );
      _putIfMeaningful(
        payload,
        'minimum_route_price',
        pricingBreakdown['minimum_route_price'] ?? quote['minimum_route_price'],
      );
      _putIfMeaningful(
        payload,
        'subtotal_before_multipliers',
        pricingBreakdown['subtotal_before_multipliers'] ??
            quote['subtotal_before_multipliers'] ??
            subtotal,
      );
      _putIfMeaningful(
        payload,
        'extra_services_total',
        pricingBreakdown['extra_services_total'] ??
            quote['extra_services_total'],
      );
      _putIfMeaningful(payload, 'aircraft_snapshot', {
        ...quote,
        'aircraft': selectedAircraftModel,
        'model': quote['model'] ?? selectedAircraftModel,
        'category': quote['cabin'] ?? quote['category'] ?? '',
        'capacity': quote['capacity'] ?? '',
        'selected_card_price': total == 0 ? null : total,
        'total': total == 0 ? null : total,
        'final_price': total == 0 ? null : total,
        'estimated_total': total == 0 ? null : total,
        'billable_hours': totalBillableHours,
        'final_billable_hours': finalBillableHours,
        'route_billable_hours': routeBillableHours,
        'debug_pricing': quote['debug_pricing'],
      });
    }

    return payload;
  }

  String? _quoteValidationMessage() {
    if (routes.isEmpty) {
      return 'Agrega al menos un tramo para cotizar.';
    }
    if (passengers <= 0) {
      return 'Indica al menos un pasajero para cotizar.';
    }

    final completeRoutes = _completeQuoteRoutes();
    if (completeRoutes.isEmpty) {
      return 'Completa origen, destino y fecha para cotizar.';
    }

    if (completeRoutes.length != routes.length) {
      return 'Completa todos los tramos antes de cotizar.';
    }

    DateTime? previousDate;
    for (var index = 0; index < completeRoutes.length; index++) {
      final route = completeRoutes[index];
      final origin = _backendAirportCode(route.fromAirport);
      final destination = _backendAirportCode(route.toAirport);
      final date = route.startDate ?? startDate;

      if (origin.isEmpty || destination.isEmpty || date == null) {
        return 'Completa origen, destino y fecha para cotizar.';
      }
      if (origin == destination) {
        return 'El origen y destino del tramo ${index + 1} deben ser diferentes.';
      }
      if (route.passengers <= 0) {
        return 'Indica pasajeros validos en el tramo ${index + 1}.';
      }
      final calendarDate = DateTime(date.year, date.month, date.day);
      if (previousDate != null && calendarDate.isBefore(previousDate)) {
        return 'Ordena las fechas de los tramos antes de cotizar.';
      }
      previousDate = calendarDate;
    }

    return null;
  }

  List<RouteModel> _completeQuoteRoutes() {
    return routes.where((route) {
      final origin = _backendAirportCode(route.fromAirport);
      final destination = _backendAirportCode(route.toAirport);
      final date = route.startDate ?? startDate;
      return origin.isNotEmpty && destination.isNotEmpty && date != null;
    }).toList();
  }

  List<Map<String, dynamic>> _normalizedBackendLegs({
    bool allowSnapshotFallback = false,
  }) {
    final normalized =
        routes
            .map((route) {
              final date = route.startDate ?? startDate;
              final dateLabel = date == null ? '' : _dateOnly(date);
              final timeLabel = date == null ? '09:00' : _timeOnly(date);
              final originIdentity = _airportIdentityForRequest(
                route.fromAirport,
                _backendAirportCode(route.fromAirport),
              );
              final destinationIdentity = _airportIdentityForRequest(
                route.toAirport,
                _backendAirportCode(route.toAirport),
              );

              return {
                'origin': _backendAirportCode(route.fromAirport),
                'destination': _backendAirportCode(route.toAirport),
                'origin_airport_id': originIdentity['id'],
                'destination_airport_id': destinationIdentity['id'],
                'origin_icao': originIdentity['icao'],
                'destination_icao': destinationIdentity['icao'],
                'origin_iata': originIdentity['iata'],
                'destination_iata': destinationIdentity['iata'],
                'origin_airport': originIdentity['airport'],
                'destination_airport': destinationIdentity['airport'],
                'date': dateLabel,
                'time': timeLabel,
                'departure_datetime':
                    dateLabel.isEmpty
                        ? ''
                        : '$dateLabel'
                            'T$timeLabel:00',
                'passengers':
                    route.passengers > 0 ? route.passengers : passengers,
              };
            })
            .where((leg) {
              return (leg['origin'] as String).isNotEmpty &&
                  (leg['destination'] as String).isNotEmpty;
            })
            .toList();
    if (normalized.isNotEmpty || !allowSnapshotFallback) {
      return normalized;
    }
    return _lastQuotedLegs
        .map((leg) => Map<String, dynamic>.from(leg))
        .toList();
  }

  void _rememberQuotedSearch(Map<String, dynamic> previewPayload) {
    final legs = previewPayload['legs'];
    if (legs is! List || legs.isEmpty) return;

    _lastQuotedLegs =
        legs
            .whereType<Map>()
            .map((leg) => Map<String, dynamic>.from(leg))
            .toList();
    _lastQuotedPassengers =
        int.tryParse(previewPayload['passengers']?.toString() ?? '') ??
        passengers;
    _lastQuotedTripTypeCode =
        previewPayload['trip_type']?.toString().trim().isNotEmpty == true
            ? previewPayload['trip_type'].toString().trim()
            : currentTripTypeCode;
    _lastQuotedTripTypeLabel =
        previewPayload['trip_label']?.toString().trim().isNotEmpty == true
            ? previewPayload['trip_label'].toString().trim()
            : currentTripTypeLabel;
  }

  void _putIfMeaningful(
    Map<String, dynamic> target,
    String key,
    dynamic value,
  ) {
    if (_hasMeaningfulValue(value)) {
      target[key] = value;
    }
  }

  Map<String, dynamic> _airportIdentityForRequest(
    Airport? airport,
    String fallbackCode,
  ) {
    final code = fallbackCode.trim().toUpperCase();
    final icao = airport?.icao?.trim().toUpperCase();
    final iata = airport?.iata?.trim().toUpperCase();
    final name = airport?.name.trim();

    final airportPayload = <String, dynamic>{};
    if (_hasMeaningfulValue(airport?.id)) {
      airportPayload['id'] = airport!.id;
    }
    if (_hasMeaningfulValue(icao)) {
      airportPayload['icao'] = icao;
    }
    if (_hasMeaningfulValue(iata)) {
      airportPayload['iata'] = iata;
    }
    if (_hasMeaningfulValue(name)) {
      airportPayload['name'] = name;
    }

    return {
      'id': airport?.id,
      'icao': _hasMeaningfulValue(icao) ? icao : code,
      'iata': _hasMeaningfulValue(iata) ? iata : null,
      'airport': airportPayload.isEmpty ? null : airportPayload,
    };
  }

  int _itineraryDays(List<Map<String, dynamic>> legs) {
    final dates =
        legs
            .map((leg) => DateTime.tryParse(leg['date']?.toString() ?? ''))
            .whereType<DateTime>()
            .toList();
    if (dates.length < 2) return 0;
    return dates.last.difference(dates.first).inDays.abs();
  }

  String _dateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String _timeOnly(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _extractQuoteMatches(
    Map<String, dynamic> payload,
  ) {
    final previewPayload =
        payload['data'] is Map
            ? Map<String, dynamic>.from(payload['data'] as Map)
            : payload;
    final flightRequest = _nestedMap(previewPayload['flight_request']);
    final raw =
        previewPayload['matches'] ??
        previewPayload['matched_options'] ??
        previewPayload['request_matches'] ??
        previewPayload['results'] ??
        previewPayload['options'] ??
        flightRequest['matched_options'] ??
        flightRequest['matches'] ??
        (payload['data'] is List ? payload['data'] : null);

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _normalizeMatches(
    Map<String, dynamic> payload, {
    required int segmentCount,
  }) {
    final rawMatches = _extractQuoteMatches(payload);
    return rawMatches
        .asMap()
        .entries
        .map(
          (entry) => _normalizeMatch(
            Map<String, dynamic>.from(entry.value),
            index: entry.key,
            segmentCount: segmentCount,
          ),
        )
        .toList();
  }

  Map<String, dynamic> _normalizeMatch(
    Map<String, dynamic> match, {
    required int index,
    required int segmentCount,
  }) {
    final aircraftRecord = _nestedMap(
      match['aircraft'] ??
          match['aeronave'] ??
          match['aircraft_record'] ??
          match['aircraftRecord'],
    );
    final backendPricing = _buildBackendPricingBreakdown(match);
    final pricing = backendPricing;
    final backendOnlyPricing = backendPricing;
    final aircraftBaseAirport = _nestedMap(match['aircraft_base_airport']);
    final repositioning = _nestedMap(match['repositioning']);
    final returnToBase = _nestedMap(match['return_to_base']);
    final debugPricing = _nestedMap(match['debug_pricing']);
    final mergedPricingSources = mergeBackendPricingSources({
      ...match,
      if (pricing != null) 'pricing': pricing,
    });
    final hasExplicitFinalBillableHours =
        _asNumber(
          backendOnlyPricing?['final_billable_hours'] ??
              match['final_billable_hours'],
          0,
        ) >
        0;
    final resolvedTotal =
        pricing != null
            ? _resolveOfficialQuoteTotal({...match, 'pricing': pricing})
            : _resolveOfficialQuoteTotal(match);

    final normalizedFinalBillableHours = _asNumber(
      backendOnlyPricing?['final_billable_hours'] ??
          match['final_billable_hours'],
      0,
    );
    final normalizedBillableHours = _asNumber(
      backendOnlyPricing?['billable_hours'] ?? match['billable_hours'],
      normalizedFinalBillableHours,
    );
    final normalizedRouteBillableHours = _asNumber(
      backendOnlyPricing?['route_billable_hours'] ??
          match['route_billable_hours'],
      0,
    );
    final timeResolution = resolveQuoteDisplayTime({
      ...match,
      if (backendOnlyPricing != null) 'pricing_breakdown': backendOnlyPricing,
      'final_billable_hours': normalizedFinalBillableHours,
      'billable_hours': normalizedBillableHours,
      'route_billable_hours': normalizedRouteBillableHours,
    });
    final normalizedTime = timeResolution.time;
    final normalizedDisplayRouteHours = extractBackendDisplayRouteHours({
      ...match,
      if (backendOnlyPricing != null) 'pricing_breakdown': backendOnlyPricing,
    });
    final normalizedIsAvailable =
        match['is_available'] == true
            ? true
            : match['is_available'] == false
            ? false
            : aircraftRecord['is_available'] == true
            ? true
            : aircraftRecord['is_available'] == false
            ? false
            : null;
    final normalizedAvailabilityStatus =
        match['availability_status'] ?? aircraftRecord['availability_status'];
    final normalizedAvailabilityReason =
        match['availability_reason'] ?? aircraftRecord['availability_reason'];
    final normalizedDebugPricing = <String, dynamic>{
      ...mergedPricingSources,
      ...debugPricing,
    };
    if (normalizedDisplayRouteHours != null &&
        normalizedDisplayRouteHours > 0) {
      normalizedDebugPricing['display_route_hours'] =
          normalizedDebugPricing['display_route_hours'] ??
          normalizedDisplayRouteHours;
    }
    if (normalizedFinalBillableHours > 0) {
      normalizedDebugPricing['final_billable_hours'] =
          normalizedDebugPricing['final_billable_hours'] ??
          normalizedFinalBillableHours;
    }
    if (normalizedBillableHours > 0) {
      normalizedDebugPricing['billable_hours'] =
          normalizedDebugPricing['billable_hours'] ?? normalizedBillableHours;
    }
    if (normalizedRouteBillableHours > 0) {
      normalizedDebugPricing['route_billable_hours'] =
          normalizedDebugPricing['route_billable_hours'] ??
          normalizedRouteBillableHours;
    }
    normalizedDebugPricing['has_explicit_final_billable_hours'] =
        hasExplicitFinalBillableHours;

    assert(() {
      final finalBillableHours =
          debugPricing['final_billable_hours'] ??
          backendOnlyPricing?['final_billable_hours'] ??
          match['final_billable_hours'];
      final totalBillableHours =
          backendOnlyPricing?['billable_hours'] ??
          match['billable_hours'] ??
          debugPricing['billable_hours'];
      final routeBillableHours =
          backendOnlyPricing?['route_billable_hours'] ??
          match['route_billable_hours'] ??
          debugPricing['route_billable_hours'];
      final tripTime =
          match['trip_time'] ??
          match['card_time'] ??
          match['display_time'] ??
          match['ui_time'] ??
          match['time'];
      final billedTime =
          match['billed_time'] ??
          match['billable_flight_time'] ??
          backendOnlyPricing?['billed_time'] ??
          backendOnlyPricing?['billable_flight_time'];
      final displayPrice =
          match['total_amount'] ??
          match['total'] ??
          match['final_price'] ??
          backendOnlyPricing?['total_amount'] ??
          backendOnlyPricing?['total'];
      debugPrint('========================================');
      debugPrint('[QUOTE NORMALIZATION]');
      debugPrint(
        'Aircraft: ${match['aircraft_name'] ?? match['name'] ?? aircraftRecord['model'] ?? 'N/A'}',
      );
      debugPrint(
        'pricing_breakdown.billable_hours = ${backendOnlyPricing?['billable_hours'] ?? match['pricing_breakdown']?['billable_hours']}',
      );
      debugPrint('top_level.billable_hours = ${match['billable_hours']}');
      debugPrint('trip_type = ${match['trip_type'] ?? currentTripTypeCode}');
      debugPrint('selected_time_source = ${timeResolution.source}');
      debugPrint('formatted_time = $normalizedTime');
      debugPrint('price = $displayPrice');
      debugPrint('pricing.final_billable_hours = $finalBillableHours');
      debugPrint('pricing.billable_hours = $totalBillableHours');
      debugPrint('pricing.route_billable_hours = $routeBillableHours');
      debugPrint('backend.trip_time = $tripTime');
      debugPrint('backend.billed_time = $billedTime');
      debugPrint("normalized quote['time'] = $normalizedTime");
      debugPrint('========================================');
      return true;
    }());

    return {
      ...match,
      'id': match['id'] ?? 'match-$index',
      'match_id':
          match['match_id'] ?? match['matched_option_id'] ?? match['id'],
      'matched_option_id':
          match['matched_option_id'] ?? match['match_id'] ?? match['id'],
      'aircraft_id':
          match['aircraft_id'] ?? match['aircraftId'] ?? aircraftRecord['id'],
      'provider_id':
          match['provider_id'] ??
          match['providerId'] ??
          _nestedMap(match['provider'])['id'] ??
          aircraftRecord['provider_id'] ??
          _nestedMap(aircraftRecord['provider'])['id'],
      'is_available': normalizedIsAvailable,
      'availability_status': normalizedAvailabilityStatus,
      'availability_reason': normalizedAvailabilityReason,
      'aircraft':
          match['aircraft_name'] ??
          match['name'] ??
          aircraftRecord['name'] ??
          aircraftRecord['model'] ??
          aircraftRecord['category'] ??
          'Aeronave verificada',
      'time': normalizedTime,
      'display_route_hours':
          normalizedDisplayRouteHours ?? match['display_route_hours'],
      'estimated_flight_minutes': _asNumber(
        pricing?['estimated_flight_minutes'] ??
            match['estimated_flight_minutes'] ??
            ((pricing?['client_display_flight_hours'] ??
                        match['client_display_flight_hours']) !=
                    null
                ? (_asNumber(
                      pricing?['client_display_flight_hours'] ??
                          match['client_display_flight_hours'],
                    ) *
                    60)
                : null),
        0,
      ),
      'billable_flight_minutes': _asNumber(
        pricing?['billable_flight_minutes'] ??
            match['billable_flight_minutes'] ??
            pricing?['billable_minutes'] ??
            match['billable_minutes'],
        0,
      ),
      'final_price':
          pricing != null
              ? _asMoney(resolvedTotal)
              : match['final_price'] ??
                  match['price'] ??
                  match['quoted_price'] ??
                  _asMoney(resolvedTotal),
      'base_price': _asNumber(
        match['base_price'] ??
            aircraftRecord['base_price'] ??
            resolvedTotal ??
            match['total'],
      ),
      'hourly_rate': _resolveHourlyRate({...aircraftRecord, ...match}),
      'priority_type':
          match['priority_type'] ??
          match['service_tier'] ??
          match['flight_package'] ??
          '',
      'priority_multiplier': _asNumber(
        match['priority_multiplier'] ?? match['service_multiplier'],
        1,
      ),
      'priority_price': _asNumber(match['priority_price']),
      'landing_fees': _asNumber(match['landing_fees'] ?? match['landing_fee']),
      'fbo_fees': _asNumber(match['fbo_fees'] ?? match['fbo']),
      'fuel_surcharge': _asNumber(match['fuel_surcharge']),
      'overnight_fees': _asNumber(
        match['overnight_fees'] ?? match['overnight_fee'],
      ),
      'taxes': _asNumber(match['taxes'] ?? match['tax']),
      'capacity': match['capacity'] ?? aircraftRecord['capacity'] ?? '',
      'status':
          match['status'] ??
          aircraftRecord['status'] ??
          aircraftRecord['aircraft_status'] ??
          '',
      'distance_km': _asNumber(
        match['distance_km'] ??
            match['route_distance_km'] ??
            match['distanceKm'] ??
            _sumLegDistance(match['legs']),
      ),
      'range_km': _asNumber(
        match['range_km'] ??
            match['aircraft_range_km'] ??
            aircraftRecord['range_km'] ??
            aircraftRecord['aircraft_range_km'],
      ),
      'model':
          match['model'] ??
          match['aircraft_model'] ??
          aircraftRecord['model'] ??
          '',
      'registration':
          match['registration'] ??
          match['matricula'] ??
          aircraftRecord['registration'] ??
          aircraftRecord['matricula'] ??
          '',
      'source_origin':
          match['source_origin'] ??
          match['origin'] ??
          aircraftRecord['base_airport'] ??
          aircraftRecord['base'] ??
          aircraftRecord['base_airport_code'] ??
          '',
      'match_reason': _resolveMatchReason(
        match['match_reason'],
        sourceOrigin:
            match['source_origin'] ??
            match['origin'] ??
            aircraftRecord['base_airport'] ??
            aircraftRecord['base'] ??
            aircraftRecord['base_airport_code'],
      ),
      'image_url': _primaryImage(match) ?? _primaryImage(aircraftRecord) ?? '',
      'images': _extractImages(match, aircraftRecord),
      'requires_repositioning':
          match['requires_repositioning'] == true ||
          _asNumber(
                match['repositioning_distance_nm'] ??
                    repositioning['distance_nm'] ??
                    match['repositioning_hours'] ??
                    repositioning['flight_hours'],
                0,
              ) >
              0,
      'selected_radius_nm': _asNumber(match['selected_radius_nm'], 0),
      'aircraft_base_airport':
          aircraftBaseAirport.isEmpty ? null : aircraftBaseAirport,
      'repositioning': repositioning.isEmpty ? null : repositioning,
      'return_to_base': returnToBase.isEmpty ? null : returnToBase,
      'trip_time': normalizedTime,
      'card_time': normalizedTime,
      'display_time': normalizedTime,
      'ui_time': normalizedTime,
      'billed_time':
          normalizeTimeText(match['billed_time']) ??
          normalizeTimeText(match['billable_flight_time']) ??
          normalizeTimeText(backendOnlyPricing?['billed_time']) ??
          normalizeTimeText(backendOnlyPricing?['billable_flight_time']) ??
          '',
      'billable_flight_time':
          normalizeTimeText(match['billable_flight_time']) ??
          normalizeTimeText(match['billed_time']) ??
          normalizeTimeText(backendOnlyPricing?['billable_flight_time']) ??
          normalizeTimeText(backendOnlyPricing?['billed_time']) ??
          '',
      'pricing_context':
          match['pricing_context'] ??
          match['pricingContext'] ??
          backendOnlyPricing,
      'pricing_breakdown': backendOnlyPricing,
      'pricing': backendOnlyPricing ?? _nestedMap(match['pricing']),
      'debug_pricing':
          normalizedDebugPricing.isEmpty ? null : normalizedDebugPricing,
      'has_explicit_final_billable_hours': hasExplicitFinalBillableHours,
      'final_billable_hours':
          hasExplicitFinalBillableHours && normalizedFinalBillableHours > 0
              ? normalizedFinalBillableHours
              : match['final_billable_hours'],
      'billable_hours':
          normalizedBillableHours > 0
              ? normalizedBillableHours
              : match['billable_hours'],
      'route_billable_hours':
          normalizedRouteBillableHours > 0
              ? normalizedRouteBillableHours
              : match['route_billable_hours'],
      'total': resolvedTotal,
      'subtotal':
          pricing != null ? pricing['subtotal'] : _asNumber(match['subtotal']),
      'utility':
          pricing != null
              ? pricing['utility']
              : _asNumber(match['utility'] ?? match['margin']),
    };
  }

  Map<String, dynamic>? _buildBackendPricingBreakdown(
    Map<String, dynamic> match,
  ) {
    final rawPricing = _nestedMap(match['pricing']);
    final rawPricingContext = _nestedMap(match['pricing_context']);
    final rawBreakdown = _nestedMap(
      match['pricing_breakdown'] ??
          match['pricingBreakdown'] ??
          match['breakdown'],
    );

    final source =
        rawBreakdown.isNotEmpty
            ? {...rawPricing, ...rawPricingContext, ...match, ...rawBreakdown}
            : {...rawPricing, ...rawPricingContext, ...match};
    final hasExplicitFinalBillableHours =
        _hasMeaningfulValue(source['final_billable_hours']) &&
        _asNumber(source['final_billable_hours'], 0) > 0;

    final billableHours = _asNumber(
      source['billable_hours'] ??
          source['billableHours'] ??
          source['final_billable_hours'],
      double.nan,
    );
    final subtotal = _asNumber(
      source['subtotal'] ?? source['subtotal_before_multipliers'],
      double.nan,
    );
    final basePrice = _asNumber(
      source['base_price'] ??
          match['base_price'] ??
          _nestedMap(match['aircraft'])['base_price'],
      double.nan,
    );
    final fuel = _asNumber(
      source['fuel'] ?? source['fuel_cost'] ?? source['fuel_surcharge'],
      double.nan,
    );
    final repositioning = _asNumber(
      source['repositioning'] ??
          source['repositioning_fee'] ??
          source['repositioningFee'],
      double.nan,
    );
    final overnight = _asNumber(
      source['overnight'] ?? source['overnight_fee'] ?? source['overnightCost'],
      double.nan,
    );
    final utility = _asNumber(
      source['utility'] ?? source['margin'] ?? source['priority_price'],
      double.nan,
    );
    final total = _asNumber(
      _nestedMap(match['pricing'])['total_amount'] ??
          source['total_amount'] ??
          _nestedMap(match['pricing_context'])['total_amount'] ??
          source['amount_due'] ??
          source['selected_card_price'] ??
          source['estimated_total'] ??
          source['total'] ??
          source['final_price'] ??
          source['finalPrice'] ??
          match['amount_due'] ??
          match['selected_card_price'] ??
          match['estimated_total'] ??
          match['final_price'] ??
          match['total'] ??
          match['price'],
      double.nan,
    );

    final hasBackendValues =
        !billableHours.isNaN ||
        !subtotal.isNaN ||
        !fuel.isNaN ||
        !repositioning.isNaN ||
        !overnight.isNaN ||
        !utility.isNaN ||
        !total.isNaN;

    if (!hasBackendValues) {
      return null;
    }

    return {
      ...Map<String, dynamic>.from(
        rawBreakdown.isNotEmpty ? rawBreakdown : source,
      ),
      'source': 'backend',
      'hasFormulaInputs': false,
      'billable_hours': billableHours.isNaN ? null : billableHours,
      'billableHours': billableHours.isNaN ? null : billableHours,
      'subtotal': subtotal.isNaN ? 0 : subtotal,
      'fuel': fuel.isNaN ? 0 : fuel,
      'repositioning': repositioning.isNaN ? 0 : repositioning,
      'overnight': overnight.isNaN ? 0 : overnight,
      'utility': utility.isNaN ? 0 : utility,
      'total': total.isNaN ? 0 : total,
      'total_amount': total.isNaN ? 0 : total,
      'estimated_flight_minutes': _asNumber(
        source['estimated_flight_minutes'],
        0,
      ),
      'billable_flight_minutes': _asNumber(
        source['billable_flight_minutes'] ?? source['billable_minutes'],
        0,
      ),
      'estimated_flight_time': source['estimated_flight_time'],
      'display_route_hours': _asNumber(
        source['display_route_hours'] ?? source['client_display_flight_hours'],
        0,
      ),
      'billable_flight_time':
          source['billable_flight_time'] ?? source['billed_time'],
      'has_explicit_final_billable_hours': hasExplicitFinalBillableHours,
      'final_billable_hours': _asNumber(source['final_billable_hours'], 0),
      'customer_flight_cost': _asNumber(
        source['customer_flight_cost'] ?? source['client_flight_cost'],
        0,
      ),
      'repositioning_cost': _asNumber(
        source['repositioning_cost'] ??
            source['initial_repositioning_cost'] ??
            source['repositioning'],
        0,
      ),
      'return_to_base_cost': _asNumber(source['return_to_base_cost'], 0),
      'airport_expenses': _asNumber(source['airport_expenses'], 0),
      'overnight_cost': _asNumber(source['overnight_cost'], 0),
      'margin_amount': _asNumber(
        source['margin_amount'] ?? source['utility'],
        0,
      ),
      'payment_fees': _asNumber(
        source['payment_fees'] ??
            source['stripe_fee'] ??
            source['administrative_fee'],
        0,
      ),
      'taxes': _asNumber(source['taxes'] ?? source['tax'], 0),
      'landing_fees': _asNumber(
        source['landing_fees'] ?? source['landing_fee'],
        0,
      ),
      'fbo_fees': _asNumber(source['fbo_fees'] ?? source['fbo'], 0),
      'airport_fees': _asNumber(
        source['airport_fees'] ?? source['airportFees'],
        0,
      ),
      'expense_fee': _asNumber(
        source['expense_fee'] ?? source['expenseFee'],
        0,
      ),
      'tax_rate': _asNumber(
        source['tax_rate'] ??
            source['taxRate'] ??
            source['iva_rate'] ??
            source['ivaRate'] ??
            '',
        0,
      ),
      'base_price': basePrice.isNaN ? 0 : basePrice,
      'hourly_rate': _asNumber(
        source['hourly_rate'] ?? source['hourlyRate'],
        0,
      ),
    };
  }

  double _resolveOfficialQuoteTotal(Map<String, dynamic> match) {
    return extractOfficialQuoteTotal(match);
  }

  // Legacy calculator retained outside the backend quote presentation flow.
  // ignore: unused_element
  Map<String, dynamic> _buildPricingBreakdown(
    Map<String, dynamic> match,
    Map<String, dynamic> aircraftRecord, {
    required int segmentCount,
  }) {
    final billableHours = _asNumber(
      match['billable_hours'] ??
          match['estimated_hours'] ??
          match['hours'] ??
          match['flight_hours'],
    );
    final operationalHourlyRate = _resolveHourlyRate({
      ...aircraftRecord,
      ...match,
    });
    final fuelBurnGallonsPerHour = _asNumber(
      match['fuel_burn_gph'] ??
          match['fuel_consumption_gph'] ??
          aircraftRecord['fuel_burn_gph'] ??
          aircraftRecord['fuel_consumption_gph'],
    );
    final jetAPrice = _asNumber(
      match['jet_a_price'] ??
          match['jet_a'] ??
          match['fuel_price'] ??
          _nestedMap(match['provider'])['jet_a_price'] ??
          aircraftRecord['jet_a_price'] ??
          _nestedMap(aircraftRecord['provider'])['jet_a_price'],
    );
    final engineReserveRate = _asNumber(
      match['engine_reserve_rate'] ??
          match['reserve_motor_rate'] ??
          aircraftRecord['engine_reserve_rate'],
    );
    final insuranceRate = _asNumber(
      match['insurance_rate'] ?? aircraftRecord['insurance_rate'],
    );
    final maintenanceRate = _asNumber(
      match['maintenance_rate'] ?? aircraftRecord['maintenance_rate'],
    );
    final crewRate = _asNumber(
      match['crew_rate'] ?? aircraftRecord['crew_rate'],
    );
    final repositioningFee = _asNumber(
      match['repositioning_fee'] ?? aircraftRecord['repositioning_fee'],
    );
    final overnightFee = _asNumber(
      match['overnight_fee'] ?? aircraftRecord['overnight_fee'],
    );
    final additionalOperationalCost = _asNumber(
      match['operational_cost'] ??
          aircraftRecord['operational_cost'] ??
          aircraftRecord['cost'],
    );
    final fixedFee = _asNumber(
      match['fixed_fee'] ??
          match['fee_fijo'] ??
          _nestedMap(match['provider'])['fixed_fee'] ??
          aircraftRecord['fixed_fee'] ??
          _nestedMap(aircraftRecord['provider'])['fixed_fee'],
    );
    final marginPercent = _asNumber(
      match['margin_percent'] ??
          match['utility_percent'] ??
          match['porcentaje_utilidad'] ??
          _nestedMap(match['provider'])['margin_percent'] ??
          aircraftRecord['margin_percent'] ??
          _nestedMap(aircraftRecord['provider'])['margin_percent'],
    );

    final operational = billableHours * operationalHourlyRate;
    final fuel = billableHours * fuelBurnGallonsPerHour * jetAPrice;
    final engineReserve = billableHours * engineReserveRate;
    final insurance = billableHours * insuranceRate;
    final maintenance = billableHours * maintenanceRate;
    final crew = billableHours * crewRate;
    final fixedFeeTotal = fixedFee * segmentCount;
    final subtotal =
        operational +
        fuel +
        engineReserve +
        insurance +
        maintenance +
        crew +
        repositioningFee +
        overnightFee +
        additionalOperationalCost +
        fixedFeeTotal;
    final utility = subtotal * marginPercent;
    final total = subtotal + utility;
    final hasFormulaInputs =
        billableHours > 0 &&
        operationalHourlyRate > 0 &&
        (fuelBurnGallonsPerHour > 0 ||
            engineReserveRate > 0 ||
            insuranceRate > 0 ||
            maintenanceRate > 0 ||
            crewRate > 0 ||
            repositioningFee > 0 ||
            overnightFee > 0 ||
            additionalOperationalCost > 0 ||
            fixedFee > 0 ||
            marginPercent > 0);

    return {
      'hasFormulaInputs': hasFormulaInputs,
      'billableHours': double.parse(billableHours.toStringAsFixed(2)),
      'segmentCount': segmentCount,
      'jetAPrice': double.parse(jetAPrice.toStringAsFixed(2)),
      'fuelBurnGallonsPerHour': double.parse(
        fuelBurnGallonsPerHour.toStringAsFixed(2),
      ),
      'engineReserveRate': double.parse(engineReserveRate.toStringAsFixed(2)),
      'insuranceRate': double.parse(insuranceRate.toStringAsFixed(2)),
      'maintenanceRate': double.parse(maintenanceRate.toStringAsFixed(2)),
      'crewRate': double.parse(crewRate.toStringAsFixed(2)),
      'repositioningFee': double.parse(repositioningFee.toStringAsFixed(2)),
      'overnightFee': double.parse(overnightFee.toStringAsFixed(2)),
      'additionalOperationalCost': double.parse(
        additionalOperationalCost.toStringAsFixed(2),
      ),
      'fixedFee': double.parse(fixedFee.toStringAsFixed(2)),
      'fixedFeeTotal': double.parse(fixedFeeTotal.toStringAsFixed(2)),
      'marginPercent': double.parse(marginPercent.toStringAsFixed(2)),
      'operational': double.parse(operational.toStringAsFixed(2)),
      'fuel': double.parse(fuel.toStringAsFixed(2)),
      'engineReserve': double.parse(engineReserve.toStringAsFixed(2)),
      'insurance': double.parse(insurance.toStringAsFixed(2)),
      'maintenance': double.parse(maintenance.toStringAsFixed(2)),
      'crew': double.parse(crew.toStringAsFixed(2)),
      'subtotal': double.parse(subtotal.toStringAsFixed(2)),
      'utility': double.parse(utility.toStringAsFixed(2)),
      'total': double.parse(total.toStringAsFixed(2)),
    };
  }

  List<Map<String, dynamic>> _filterMatchesForItinerary(
    List<Map<String, dynamic>> matches,
    Airport? originAirport,
  ) {
    if (matches.isEmpty || originAirport == null) return matches;

    final filtered =
        matches
            .where((match) {
              final status = _normalizeStatus(match['status']);
              return _activeQuoteStatuses.contains(status);
            })
            .where((match) {
              final capacity = _extractCapacity(match['capacity']);
              return capacity == 0 || capacity >= passengers;
            })
            .map((match) {
              final sourceOrigin = match['source_origin']?.toString() ?? '';
              final baseAirportMatch = _originMatches(
                sourceOrigin,
                originAirport,
              );
              return {
                ...match,
                'base_airport_match': baseAirportMatch,
                'queried_base_airport':
                    originAirport.iata?.isNotEmpty == true
                        ? originAirport.iata!
                        : originAirport.name,
                'match_reason': _resolveMatchReason(
                  match['match_reason'],
                  sourceOrigin: sourceOrigin,
                  baseAirportMatch: baseAirportMatch,
                ),
              };
            })
            .toList();

    return filtered;
  }

  double _quoteOfficialTotalValue(Map<String, dynamic> match) {
    return extractOfficialQuoteTotal(match);
  }

  String _quotePreviewErrorMessage(ApiException error) {
    final normalized = error.message.trim();
    if (normalized.contains('tardo demasiado')) {
      return 'El servidor tardó demasiado en responder. Intenta nuevamente en unos momentos.';
    }
    if (normalized.contains('No fue posible conectar')) {
      return 'No fue posible conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.';
    }
    if ((error.statusCode ?? 0) >= 500) {
      return 'El servidor no pudo completar la cotización. Intenta nuevamente en unos momentos.';
    }
    return normalized.isEmpty
        ? 'No fue posible obtener una cotización real.'
        : normalized;
  }

  String _normalizeStatus(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  int _extractCapacity(dynamic value) {
    final raw = value?.toString() ?? '';
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(raw);
    return int.tryParse(match?.group(1)?.split('.').first ?? '') ?? 0;
  }

  double _sumLegDistance(dynamic legs) {
    if (legs is! List) return 0;
    return legs.fold<double>(0, (sum, leg) {
      if (leg is! Map) return sum;
      return sum + _asNumber(leg['distance_km']);
    });
  }

  String _resolveMatchReason(
    dynamic rawReason, {
    dynamic sourceOrigin,
    bool baseAirportMatch = false,
  }) {
    final base = sourceOrigin?.toString().trim() ?? '';
    if (baseAirportMatch && base.isNotEmpty) {
      return 'Base operativa en $base';
    }

    final reason = rawReason?.toString().trim() ?? '';
    if (reason.isNotEmpty && !reason.toLowerCase().contains('base_airport')) {
      return reason;
    }

    if (base.isNotEmpty) return 'Salida optimizada desde $base';
    return 'Opcion verificada';
  }

  Map<String, dynamic>? _pickSelectedQuoteMatch(
    List<Map<String, dynamic>> matches,
  ) {
    if (matches.isEmpty) return null;

    final selectedId = selectedAircraft?.id;
    if (selectedId != null) {
      for (final match in matches) {
        final aircraftId =
            match['aircraft_id']?.toString() ??
            ((match['aircraft'] is Map)
                ? match['aircraft']['id']?.toString()
                : null);
        if (aircraftId == selectedId) {
          return match;
        }
      }
    }

    return matches.first;
  }

  String get currentTripTypeCode {
    switch (bookingTripLabel) {
      case 'Ida y vuelta':
        return 'round_trip';
      case 'Multidestino':
        return 'multi_leg';
      default:
        return 'one_way';
    }
  }

  String get currentTripTypeLabel {
    switch (bookingTripLabel) {
      case 'Ida y vuelta':
        return 'Redondo';
      case 'Multidestino':
        return 'Multi-destino';
      default:
        return 'Ida';
    }
  }

  List<Map<String, dynamic>> buildRequirementsPayload() {
    return routes
        .skip(1)
        .map((route) {
          return {
            'origin': _backendAirportCode(route.fromAirport),
            'destination': _backendAirportCode(route.toAirport),
            'date':
                (route.startDate ?? startDate)
                    ?.toIso8601String()
                    .split('T')
                    .first,
            'time': _timeStringForRoute(route),
            'passengers': route.passengers,
          };
        })
        .where((route) {
          return (route['origin'] as String).isNotEmpty &&
              (route['destination'] as String).isNotEmpty;
        })
        .toList();
  }

  List<Map<String, dynamic>> buildLegsPayload() {
    return routes
        .map((route) {
          return {
            'origin': _backendAirportCode(route.fromAirport),
            'destination': _backendAirportCode(route.toAirport),
            'date':
                (route.startDate ?? startDate)
                    ?.toIso8601String()
                    .split('T')
                    .first,
            'time': _timeStringForRoute(route),
            'passengers': route.passengers > 0 ? route.passengers : passengers,
          };
        })
        .where((route) {
          return (route['origin'] as String).isNotEmpty &&
              (route['destination'] as String).isNotEmpty &&
              route['date'] != null;
        })
        .toList();
  }

  Map<String, dynamic>? _createdFlightRequestRecord(
    Map<String, dynamic> response,
  ) {
    final data = _nestedMap(response['data']);
    final candidates = [
      response['flight_request'],
      data['flight_request'],
      data['request'],
      response['reservation'],
      response['trip'],
      data,
      response,
    ];

    for (final candidate in candidates) {
      if (candidate is! Map) continue;
      final record = Map<String, dynamic>.from(candidate);
      if (_looksLikeFlightRequestRecord(record)) return record;
    }

    return null;
  }

  List<Map<String, dynamic>> _mergeFlightHistoryRows(
    List<Map<String, dynamic>> rows,
  ) {
    final merged = <Map<String, dynamic>>[];
    final indexByAlias = <String, int>{};

    for (final raw in rows) {
      final normalized = _normalizeFlightHistoryRow(raw);
      final aliases = _mergeAliasesForFlightHistoryRow(normalized);
      int? currentIndex;
      for (final alias in aliases) {
        final matchedIndex = indexByAlias[alias];
        if (matchedIndex != null &&
            _canMergeFlightHistoryRows(
              merged[matchedIndex],
              normalized,
              matchedAlias: alias,
            )) {
          currentIndex = matchedIndex;
          break;
        }
      }

      if (currentIndex != null) {
        merged[currentIndex] = _mergeFlightHistoryRecord(
          merged[currentIndex],
          normalized,
        );
        final updatedAliases = _mergeAliasesForFlightHistoryRow(
          merged[currentIndex],
        );
        for (final alias in updatedAliases) {
          indexByAlias[alias] = currentIndex;
        }
        continue;
      }

      final nextIndex = merged.length;
      merged.add(normalized);
      for (final alias in aliases) {
        indexByAlias[alias] = nextIndex;
      }
    }

    return merged;
  }

  Set<String> _mergeAliasesForFlightHistoryRow(Map<String, dynamic> row) {
    final aliases = <String>{};

    final flightRequestId = _flightHistoryFlightRequestId(row);
    if (flightRequestId != null && flightRequestId.isNotEmpty) {
      aliases.add('flight_request:$flightRequestId');
    }

    final reservationId = _flightHistoryReservationId(row);
    if (reservationId != null && reservationId.isNotEmpty) {
      aliases.add('reservation:$reservationId');
    }

    final requestNumber = _flightHistoryRequestNumber(row);
    if (requestNumber != null && requestNumber.isNotEmpty) {
      aliases.add('request_number:$requestNumber');
    }

    final rowId = _resolveEntityId(row);
    if (aliases.isEmpty && rowId != null && rowId.isNotEmpty) {
      aliases.add('entity:$rowId');
    }

    final businessKey = _flightHistoryBusinessKey(row);
    if (businessKey.isNotEmpty) {
      aliases.add('business:$businessKey');
    }

    if (aliases.isEmpty) {
      final fallback = [
        row['origin'],
        row['destination'],
        row['departure_datetime'],
        row['created_at'],
      ].whereType<Object>().join('|');
      if (fallback.isNotEmpty) {
        aliases.add('fallback:$fallback');
      }
    }

    return aliases;
  }

  bool _canMergeFlightHistoryRows(
    Map<String, dynamic> current,
    Map<String, dynamic> incoming, {
    required String matchedAlias,
  }) {
    if (_sharesStrongFlightHistoryIdentity(current, incoming)) {
      return true;
    }

    if (_hasConflictingStrongFlightHistoryIdentity(current, incoming)) {
      return false;
    }

    final currentHasStrong = _hasStrongFlightHistoryIdentity(current);
    final incomingHasStrong = _hasStrongFlightHistoryIdentity(incoming);

    if (currentHasStrong && incomingHasStrong) {
      return false;
    }

    return matchedAlias.startsWith('business:') ||
        matchedAlias.startsWith('fallback:') ||
        matchedAlias.startsWith('entity:');
  }

  bool _sharesStrongFlightHistoryIdentity(
    Map<String, dynamic> current,
    Map<String, dynamic> incoming,
  ) {
    final currentReservationId = _flightHistoryReservationId(current);
    final incomingReservationId = _flightHistoryReservationId(incoming);
    if (currentReservationId != null &&
        incomingReservationId != null &&
        currentReservationId == incomingReservationId) {
      return true;
    }

    final currentFlightRequestId = _flightHistoryFlightRequestId(current);
    final incomingFlightRequestId = _flightHistoryFlightRequestId(incoming);
    if (currentFlightRequestId != null &&
        incomingFlightRequestId != null &&
        currentFlightRequestId == incomingFlightRequestId) {
      return true;
    }

    final currentRequestNumber = _flightHistoryRequestNumber(current);
    final incomingRequestNumber = _flightHistoryRequestNumber(incoming);
    return currentRequestNumber != null &&
        incomingRequestNumber != null &&
        currentRequestNumber == incomingRequestNumber;
  }

  bool _hasConflictingStrongFlightHistoryIdentity(
    Map<String, dynamic> current,
    Map<String, dynamic> incoming,
  ) {
    final currentReservationId = _flightHistoryReservationId(current);
    final incomingReservationId = _flightHistoryReservationId(incoming);
    if (currentReservationId != null &&
        incomingReservationId != null &&
        currentReservationId != incomingReservationId) {
      return true;
    }

    final currentFlightRequestId = _flightHistoryFlightRequestId(current);
    final incomingFlightRequestId = _flightHistoryFlightRequestId(incoming);
    if (currentFlightRequestId != null &&
        incomingFlightRequestId != null &&
        currentFlightRequestId != incomingFlightRequestId) {
      return true;
    }

    final currentRequestNumber = _flightHistoryRequestNumber(current);
    final incomingRequestNumber = _flightHistoryRequestNumber(incoming);
    return currentRequestNumber != null &&
        incomingRequestNumber != null &&
        currentRequestNumber != incomingRequestNumber;
  }

  bool _hasStrongFlightHistoryIdentity(Map<String, dynamic> row) {
    return _flightHistoryReservationId(row) != null ||
        _flightHistoryFlightRequestId(row) != null ||
        _flightHistoryRequestNumber(row) != null;
  }

  String? _flightHistoryReservationId(Map<String, dynamic> row) {
    final reservation = _nestedMap(row['reservation']);
    return _resolveEntityId(row['reservation_id']) ??
        _resolveEntityId(row['booking_id']) ??
        _resolveEntityId(reservation['id']);
  }

  String? _flightHistoryFlightRequestId(Map<String, dynamic> row) {
    final reservation = _nestedMap(row['reservation']);
    final flightRequest = _nestedMap(row['flight_request']);
    return _resolveEntityId(row['flight_request_id']) ??
        _resolveEntityId(row['request_id']) ??
        _resolveEntityId(flightRequest['id']) ??
        _resolveEntityId(reservation['flight_request_id']);
  }

  String? _flightHistoryRequestNumber(Map<String, dynamic> row) {
    final reservation = _nestedMap(row['reservation']);
    final flightRequest = _nestedMap(row['flight_request']);
    final value =
        _firstText(row, const [
          'request_number',
          'folio',
          'booking_code',
          'reservation_code',
          'code',
        ]) ??
        _firstText(reservation, const [
          'request_number',
          'folio',
          'booking_code',
          'reservation_code',
          'code',
        ]) ??
        _firstText(flightRequest, const [
          'request_number',
          'folio',
          'booking_code',
          'reservation_code',
          'code',
        ]);
    final normalized = value?.trim().toUpperCase() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  String _flightHistoryBusinessKey(Map<String, dynamic> row) {
    final aircraftId =
        _firstText(row, const ['assigned_aircraft_id', 'aircraft_id']) ??
        _firstText(_nestedMap(row['reservation']), const [
          'assigned_aircraft_id',
          'aircraft_id',
        ]) ??
        _firstText(_nestedMap(row['flight_request']), const [
          'assigned_aircraft_id',
          'aircraft_id',
        ]) ??
        '';
    final aircraftLabel =
        _firstText(row, const [
          'assigned_aircraft_model',
          'aircraft_model',
          'aircraft_name',
          'aircraft',
        ]) ??
        _firstText(_nestedMap(row['reservation']), const [
          'assigned_aircraft_model',
          'aircraft_model',
          'aircraft_name',
          'aircraft',
        ]) ??
        _firstText(_nestedMap(row['flight_request']), const [
          'assigned_aircraft_model',
          'aircraft_model',
          'aircraft_name',
          'aircraft',
        ]) ??
        '';
    final origin =
        (_firstText(row, const ['origin']) ?? '').trim().toUpperCase();
    final destination =
        (_firstText(row, const ['destination']) ?? '').trim().toUpperCase();
    final departureDateTime =
        (_firstText(row, const ['departure_datetime', 'date']) ?? '').trim();
    final passengers =
        (_firstText(row, const ['passengers']) ?? '').trim().toUpperCase();
    final aircraftKey =
        aircraftId.trim().isNotEmpty
            ? aircraftId.trim().toUpperCase()
            : aircraftLabel.trim().toUpperCase();

    if (aircraftKey.isEmpty ||
        origin.isEmpty ||
        destination.isEmpty ||
        departureDateTime.isEmpty) {
      return '';
    }

    return [
      aircraftKey,
      origin,
      destination,
      departureDateTime,
      passengers,
    ].join('::');
  }

  Map<String, dynamic> _mergeFlightHistoryRecord(
    Map<String, dynamic> current,
    Map<String, dynamic> incoming,
  ) {
    final merged = Map<String, dynamic>.from(current);
    final preferIncomingWorkflow = _incomingWorkflowShouldWin(
      current,
      incoming,
    );

    for (final entry in incoming.entries) {
      final incomingValue = entry.value;
      final currentValue = merged[entry.key];

      if (_shouldReplaceMergedValue(
        key: entry.key,
        currentValue: currentValue,
        incomingValue: incomingValue,
        preferIncomingWorkflow: preferIncomingWorkflow,
      )) {
        merged[entry.key] = incomingValue;
        continue;
      }

      if (_hasMeaningfulValue(incomingValue) &&
          !_hasMeaningfulValue(currentValue)) {
        merged[entry.key] = incomingValue;
        continue;
      }

      if (entry.key == 'contract' && incomingValue is Map) {
        merged[entry.key] = _mergeMeaningfulMaps(
          _nestedMap(currentValue),
          Map<String, dynamic>.from(incomingValue),
          preferIncoming: preferIncomingWorkflow,
        );
        continue;
      }

      if (entry.key == 'frontend_state' && incomingValue is Map) {
        merged[entry.key] = _mergeMeaningfulMaps(
          _nestedMap(currentValue),
          Map<String, dynamic>.from(incomingValue),
          preferIncoming: preferIncomingWorkflow,
        );
        continue;
      }

      if (const {
            'reservation',
            'flight_request',
            'operation',
          }.contains(entry.key) &&
          incomingValue is Map) {
        merged[entry.key] = _mergeMeaningfulMaps(
          _nestedMap(currentValue),
          Map<String, dynamic>.from(incomingValue),
          preferIncoming: preferIncomingWorkflow,
        );
        continue;
      }
    }

    return _normalizeFlightHistoryRow(merged);
  }

  bool _incomingWorkflowShouldWin(
    Map<String, dynamic> current,
    Map<String, dynamic> incoming,
  ) {
    final incomingExplicitWorkflowId = resolveClientWorkflowStageIdFromValue(
      _firstText(incoming, const ['workflow_status', 'workflow', 'status']) ??
          '',
    );
    if (const [
          'contract_pending',
          'contract_signed',
          'payment_pending',
        ].contains(incomingExplicitWorkflowId) &&
        !_hasTopLevelPaidSignal(incoming)) {
      return true;
    }

    final currentRank = _workflowStageRank(current);
    final incomingRank = _workflowStageRank(incoming);

    if (incomingRank != currentRank) {
      return incomingRank > currentRank;
    }

    final currentUpdatedAt = _recordTimestamp(current);
    final incomingUpdatedAt = _recordTimestamp(incoming);

    return incomingUpdatedAt > currentUpdatedAt;
  }

  int _workflowStageRank(Map<String, dynamic> row) {
    switch (resolveClientWorkflowStage(row)) {
      case 'draft':
        return 0;
      case 'quoted':
        return 1;
      case 'package_selected':
        return 2;
      case 'reserved':
        return 3;
      case 'provider_pending':
        return 4;
      case 'provider_accepted':
        return 5;
      case 'contract_pending':
        return 6;
      case 'contract_signed':
        return 7;
      case 'payment_pending':
        return 8;
      case 'payment_confirmed':
        return 9;
      case 'flight_confirmed':
        return 10;
      case 'tracking_live':
        return 11;
      case 'completed':
        return 12;
      case 'rejected':
      case 'cancelled':
        return 13;
      default:
        return -1;
    }
  }

  int _recordTimestamp(Map<String, dynamic> row) {
    final reservation = _nestedMap(row['reservation']);
    final flightRequest = _nestedMap(row['flight_request']);
    final operation = _nestedMap(row['operation']);
    final raw =
        _firstText(row, const [
          'updated_at',
          'completed_at',
          'closed_at',
          'paid_at',
          'departure_datetime',
          'created_at',
        ]) ??
        _firstText(reservation, const [
          'updated_at',
          'completed_at',
          'closed_at',
          'paid_at',
          'created_at',
        ]) ??
        _firstText(flightRequest, const ['updated_at', 'created_at']) ??
        _firstText(operation, const ['updated_at', 'created_at']) ??
        '';
    return DateTime.tryParse(raw)?.millisecondsSinceEpoch ?? 0;
  }

  bool _shouldReplaceMergedValue({
    required String key,
    required dynamic currentValue,
    required dynamic incomingValue,
    required bool preferIncomingWorkflow,
  }) {
    if (!_hasMeaningfulValue(incomingValue)) return false;
    if (!_hasMeaningfulValue(currentValue)) return true;

    if (!preferIncomingWorkflow) {
      return false;
    }

    return const {
      'status',
      'workflow_status',
      'reservation_status',
      'flight_status',
      'tracking_status',
      'crew_status',
      'payment_status',
      'contract_status',
      'next_action',
      'origin',
      'destination',
      'departure_datetime',
      'assigned_aircraft_id',
      'assigned_aircraft_model',
      'aircraft_id',
      'aircraft_model',
      'aircraft',
      'aircraft_capacity',
      'capacity',
      'provider_name',
      'image_url',
      'imageUrl',
      'folio',
      'booking_code',
      'reservation_code',
      'legs',
      'segments',
      'routes',
      'requirements',
      'reservation',
      'flight_request',
      'operation',
      'operation_id',
    }.contains(key);
  }

  Map<String, dynamic> _mergeMeaningfulMaps(
    Map<String, dynamic> current,
    Map<String, dynamic> incoming, {
    required bool preferIncoming,
  }) {
    final merged = <String, dynamic>{...current};

    for (final entry in incoming.entries) {
      final currentValue = merged[entry.key];
      final incomingValue = entry.value;

      if (!_hasMeaningfulValue(currentValue) &&
          _hasMeaningfulValue(incomingValue)) {
        merged[entry.key] = incomingValue;
        continue;
      }

      if (preferIncoming && _hasMeaningfulValue(incomingValue)) {
        merged[entry.key] = incomingValue;
      }
    }

    return merged;
  }

  Map<String, dynamic> _normalizeFlightHistoryRow(Map<String, dynamic> raw) {
    final row = Map<String, dynamic>.from(raw);
    final aircraft = _nestedMap(
      row['assigned_aircraft'] ?? row['aircraft_data'] ?? row['aircraft'],
    );
    final provider = _nestedMap(
      row['provider'] ?? row['assigned_provider'] ?? row['operator'],
    );
    final firstLeg = _firstLeg(row);
    final reservation = _nestedMap(row['reservation']);

    final id =
        _resolveEntityId(row) ??
        _resolveEntityId(reservation) ??
        _resolveEntityId(row['flight_request']);
    final origin =
        row['origin'] ??
        row['from'] ??
        row['departure_airport'] ??
        firstLeg['origin'] ??
        firstLeg['from'];
    final destination =
        row['destination'] ??
        row['to'] ??
        row['arrival_airport'] ??
        firstLeg['destination'] ??
        firstLeg['to'];
    final departure =
        row['departure_datetime'] ??
        row['start_datetime'] ??
        row['departure_at'] ??
        row['scheduled_at'] ??
        row['date'] ??
        firstLeg['departure_datetime'] ??
        firstLeg['date'];

    return {
      ...row,
      if (id != null) 'id': id,
      if (row['flight_request_id'] == null)
        'flight_request_id':
            row['request_id'] ??
            _resolveEntityId(_nestedMap(row['flight_request'])['id']) ??
            _resolveEntityId(
              _nestedMap(row['reservation'])['flight_request_id'],
            ),
      if (row['reservation_id'] == null)
        'reservation_id':
            row['booking_id'] ??
            _resolveEntityId(_nestedMap(row['reservation'])['id']),
      if (origin != null) 'origin': origin,
      if (destination != null) 'destination': destination,
      if (departure != null) 'departure_datetime': departure,
      if (row['assigned_aircraft_model'] == null)
        'assigned_aircraft_model':
            row['aircraft_model'] ??
            aircraft['model'] ??
            aircraft['name'] ??
            aircraft['registration'],
      if (row['assigned_aircraft_id'] == null)
        'assigned_aircraft_id': aircraft['id'] ?? row['aircraft_id'],
      if (row['provider_name'] == null)
        'provider_name':
            provider['name'] ??
            provider['company_name'] ??
            row['operator_name'],
      if (row['image_url'] == null && row['imageUrl'] == null)
        'image_url': _primaryImage(row) ?? _primaryImage(aircraft) ?? '',
    };
  }

  List<Map<String, dynamic>> _paymentsFromRow(Map<String, dynamic> row) {
    final direct = row['payments'];
    if (direct is List) {
      return direct
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    final reservation = _nestedMap(row['reservation']);
    final nested = reservation['payments'];
    if (nested is List) {
      return nested
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return const [];
  }

  bool _hasTopLevelPaidSignal(Map<String, dynamic> row) {
    final payment = _nestedMap(row['payment']);
    final paymentOrder = _nestedMap(row['payment_order']);

    return _isPaidStatus(row['workflow_status']?.toString().trim() ?? '') ||
        _isPaidStatus(row['status']?.toString().trim() ?? '') ||
        _isPaidStatus(row['payment_status']?.toString().trim() ?? '') ||
        _isPaidStatus(row['checkout_status']?.toString().trim() ?? '') ||
        _isPaidStatus(payment['status']?.toString().trim() ?? '') ||
        _isPaidStatus(paymentOrder['status']?.toString().trim() ?? '');
  }

  bool _isPaidStatus(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'paid' ||
        normalized == 'pagado' ||
        normalized == 'pagada' ||
        normalized == 'payment_confirmed' ||
        normalized == 'payment confirmed' ||
        normalized == 'pago confirmado';
  }

  String? _firstText(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return null;
  }

  Map<String, dynamic> _firstLeg(Map<String, dynamic> row) {
    final legs = row['legs'] ?? row['segments'] ?? row['routes'];
    if (legs is List && legs.isNotEmpty && legs.first is Map) {
      return Map<String, dynamic>.from(legs.first as Map);
    }
    return const {};
  }

  bool _looksLikeFlightRequestRecord(Map<String, dynamic> record) {
    return _resolveEntityId(record) != null ||
        record.containsKey('origin') ||
        record.containsKey('destination') ||
        record.containsKey('departure_datetime') ||
        record.containsKey('flight_request_id') ||
        record.containsKey('reservation_id');
  }

  String? _resolveEntityId(dynamic value) {
    if (value == null) return null;
    if (value is String || value is num) {
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }
    if (value is Map) {
      final record = Map<String, dynamic>.from(value);
      for (final key in const [
        'id',
        'reservation_id',
        'flight_request_id',
        'request_id',
        'booking_id',
      ]) {
        final id = _resolveEntityId(record[key]);
        if (id != null) return id;
      }
    }
    return null;
  }

  bool _hasMeaningfulValue(dynamic value) {
    if (value == null) return false;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized.isNotEmpty &&
          normalized != 'null' &&
          normalized != 'ruta por confirmar' &&
          normalized != 'fecha por confirmar';
    }
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  Map<String, dynamic> _nestedMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const {};
  }

  double _asNumber(dynamic value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(RegExp(r'[^0-9.\-]'), '');
      return double.tryParse(normalized) ?? fallback;
    }
    return fallback;
  }

  String _asMoney(dynamic value) {
    final amount = _asNumber(value, double.nan);
    if (amount.isNaN) return value?.toString() ?? '';
    return _currencyFormat.format(amount);
  }

  double _resolveHourlyRate(Map<String, dynamic> raw) {
    return _asNumber(
      raw['hourly_rate'] ??
          raw['hourly_price'] ??
          raw['price_per_hour'] ??
          raw['cost_per_hour'] ??
          raw['costPerHour'] ??
          raw['rental_price_usd'] ??
          raw['rentalPriceUsd'] ??
          raw['charter_rate'] ??
          raw['charterRate'] ??
          raw['rate_per_hour'] ??
          raw['ratePerHour'] ??
          raw['cost'],
    );
  }

  String? _primaryImage(Map<String, dynamic> raw) {
    final candidates = [
      raw['main_image'],
      raw['mainImage'],
      raw['image_url'],
      raw['imageUrl'],
      raw['image'],
      raw['image_path'],
      raw['imagePath'],
      raw['photo'],
      raw['photo_url'],
      raw['photoUrl'],
      raw['cover_image'],
      raw['coverImage'],
      raw['thumbnail'],
      raw['thumbnail_url'],
      raw['thumbnailUrl'],
      raw['exterior_image'],
      raw['interior_image'],
      raw['aircraft_image'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    return null;
  }

  List<Map<String, dynamic>> _extractImages(
    Map<String, dynamic> raw,
    Map<String, dynamic> aircraftRecord,
  ) {
    final collections = [
      raw['images'],
      raw['aircraft_images'],
      raw['gallery_images'],
      raw['gallery'],
      raw['photos'],
      aircraftRecord['images'],
      aircraftRecord['aircraft_images'],
    ];

    final result = <Map<String, dynamic>>[];
    var index = 0;
    for (final collection in collections) {
      if (collection is! List) continue;
      for (final item in collection) {
        final itemMap = _nestedMap(item);
        final imageUrl =
            _primaryImage(itemMap) ??
            itemMap['url']?.toString().trim() ??
            itemMap['path']?.toString().trim() ??
            '';
        if (imageUrl.isEmpty) continue;
        result.add({
          'id': itemMap['id'] ?? 'image-$index',
          'title':
              itemMap['title'] ??
              itemMap['name'] ??
              itemMap['kind'] ??
              'Imagen ${index + 1}',
          'kind': itemMap['kind'] ?? (index == 0 ? 'main' : 'gallery'),
          'imageUrl': imageUrl,
        });
        index++;
      }
    }

    final primary = _primaryImage(raw) ?? _primaryImage(aircraftRecord);
    if (primary != null &&
        primary.isNotEmpty &&
        !result.any((image) => image['imageUrl'] == primary)) {
      result.insert(0, {
        'id': 'main-image',
        'title': 'Imagen principal',
        'kind': 'main',
        'imageUrl': primary,
      });
    }

    return result;
  }

  String _normalizeLookup(dynamic value) {
    return value?.toString().trim().toUpperCase().replaceAll(
          RegExp(r'[_\-\s]+'),
          ' ',
        ) ??
        '';
  }

  bool _originMatches(String baseValue, Airport? originAirport) {
    if (originAirport == null) return false;
    final base = _normalizeLookup(baseValue);
    if (base.isEmpty) return false;

    final candidates = {
      _normalizeLookup(originAirport.icao),
      _normalizeLookup(originAirport.iata),
      _normalizeLookup(originAirport.city),
      _normalizeLookup(originAirport.name),
      _normalizeLookup('${originAirport.city} ${originAirport.icao ?? ''}'),
      _normalizeLookup('${originAirport.city} ${originAirport.iata ?? ''}'),
    }..remove('');

    return candidates.any(
      (candidate) => base.contains(candidate) || candidate.contains(base),
    );
  }

  String _backendAirportCode(Airport? airport) {
    if (airport == null) return '';

    final icao = airport.icao?.trim().toUpperCase() ?? '';
    if (icao.length == 4) return icao;

    final iata = airport.iata?.trim().toUpperCase() ?? '';
    if (iata.isNotEmpty) return iata;

    return airport.name.trim();
  }

  String _timeStringForRoute(RouteModel route) {
    final date = route.startDate ?? startDate;
    if (date == null) return '09:00';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  List<Aircraft> get filteredFleet {
    if (flightType == null) return aircraftFleet;

    final type = flightType!.toUpperCase();

    return aircraftFleet.where((aircraft) {
      final currentAircraftType = aircraft.aircraftType.toUpperCase();

      if (type == 'JET PRIVADO' || type == 'PRIVATE JET') {
        return currentAircraftType.contains('JET');
      }

      if (type == 'HELICOPTERO' || type == 'HELICOPTER') {
        return currentAircraftType.contains('HELICOPTERO') ||
            currentAircraftType.contains('HELICOPTER');
      }

      if (type == 'AMBULANCIA AEREA' || type == 'AIR AMBULANCE') {
        return currentAircraftType.contains('JET');
      }

      if (type == 'CARGA' || type == 'CARGO') {
        return currentAircraftType.contains('TURBO');
      }

      return true;
    }).toList();
  }

  void setGlobalPassengers(int value) {
    passengers = value < 1 ? 1 : value;
    for (final route in routes) {
      route.passengers = passengers;
    }
    notifyListeners();
  }

  void setGlobalStartDate(DateTime date) {
    startDate = date;
    notifyListeners();
  }

  void setGlobalEndDate(DateTime date) {
    endDate = date;
    notifyListeners();
  }

  void setFlightType(String type) {
    flightType = type;
    selectedAircraft = null;
    notifyListeners();
  }

  void setRouteType(String type) {
    routeType = type;
    routes = [RouteModel()];
    selectedAircraft = null;
    notifyListeners();
  }

  void setBookingTripLabel(String value) {
    bookingTripLabel = value;
    notifyListeners();
  }

  void setSelectedPriorityType(String value) {
    if (value.trim().isEmpty) return;
    selectedPriorityType = value.trim();
    notifyListeners();
  }

  void setPets(String value) {
    pets = value;
    notifyListeners();
  }

  void setSpecialBaggage(String value) {
    specialBaggage = value;
    notifyListeners();
  }

  void setPreference(String value) {
    preference = value;
    notifyListeners();
  }

  void setConciergeRequested(bool value) {
    conciergeRequested = value;
    notifyListeners();
  }

  void setName(String value) {
    name = value;
    notifyListeners();
  }

  void setEmail(String value) {
    email = value;
    notifyListeners();
  }

  void setPhone(String value) {
    phone = value;
    notifyListeners();
  }

  void setFullName(String value) {
    fullName = value;
    notifyListeners();
  }

  void addRoute({bool allowIncomplete = false}) {
    if (routes.isEmpty) {
      routes.add(RouteModel());
      notifyListeners();
      return;
    }

    final lastRoute = routes.last;

    if (lastRoute.toAirport == null && !allowIncomplete) {
      return;
    }

    routes.add(
      RouteModel(
        fromAirport: lastRoute.toAirport,
        passengers: lastRoute.passengers,
      ),
    );

    notifyListeners();
  }

  void removeRoute(int index) {
    if (routes.length <= 1) return;

    routes.removeAt(index);

    if (index > 0 && index < routes.length) {
      routes[index].fromAirport = routes[index - 1].toAirport;
    }

    notifyListeners();
  }

  void setFromAirport(int index, Airport? airport) {
    if (index >= routes.length) return;

    routes[index].fromAirport = airport;
    notifyListeners();
  }

  void setToAirport(int index, Airport? airport) {
    if (index >= routes.length) return;

    routes[index].toAirport = airport;

    if (index + 1 < routes.length) {
      routes[index + 1].fromAirport = airport;
    }

    notifyListeners();
  }

  void setPassengers(int index, int value) {
    if (index >= routes.length) return;

    routes[index].passengers = value < 1 ? 1 : value;
    notifyListeners();
  }

  void setStartDate(int index, DateTime date) {
    if (index >= routes.length) return;

    routes[index].startDate = date;
    notifyListeners();
  }

  void setEndDate(int index, DateTime date) {
    if (index >= routes.length) return;

    routes[index].endDate = date;
    notifyListeners();
  }

  void setAircraft(Aircraft? aircraft) {
    selectedAircraft = aircraft;
    notifyListeners();
  }

  void setSelectedQuoteMatch(Map<String, dynamic>? value) {
    selectedQuoteMatch =
        value == null ? null : Map<String, dynamic>.from(value);
    notifyListeners();
  }

  void handleAircraftUnavailable(Map<String, dynamic> request) {
    final unavailableId =
        _firstText(request, const ['aircraft_id', 'assigned_aircraft_id']) ??
        _firstText(_nestedMap(request['aircraft']), const ['id']) ??
        '';
    final unavailableMatchId =
        _firstText(request, const ['match_id', 'matched_option_id']) ?? '';

    selectedAircraft = null;
    selectedQuoteMatch = null;
    quoteMatches =
        quoteMatches.where((quote) {
          final quoteAircraftId =
              _firstText(quote, const [
                'aircraft_id',
                'assigned_aircraft_id',
              ]) ??
              _firstText(_nestedMap(quote['aircraft']), const ['id']) ??
              '';
          final quoteMatchId =
              _firstText(quote, const [
                'match_id',
                'matched_option_id',
                'id',
              ]) ??
              '';
          if (unavailableId.isNotEmpty && quoteAircraftId == unavailableId) {
            return false;
          }
          if (unavailableMatchId.isNotEmpty &&
              quoteMatchId == unavailableMatchId) {
            return false;
          }
          return true;
        }).toList();
    quoteError =
        'La aeronave seleccionada ya no esta disponible. Elige otra opcion; tu solicitud y datos de busqueda se conservaron.';
    notifyListeners();
  }

  Map<String, dynamic> exportSearchDraft() {
    return {
      'passengers': passengers,
      'trip_type': currentTripTypeCode,
      'trip_label': bookingTripLabel,
      'priority_type': selectedPriorityType,
      'pets': pets,
      'special_baggage': specialBaggage,
      'preference': preference,
      'concierge_requested': conciergeRequested,
      'selected_aircraft_id': selectedAircraft?.id ?? '',
      'routes':
          routes.map((route) {
            return {
              'origin': _backendAirportCode(route.fromAirport),
              'destination': _backendAirportCode(route.toAirport),
              'departure_datetime': route.startDate?.toIso8601String(),
              'end_datetime': route.endDate?.toIso8601String(),
              'passengers': route.passengers,
            };
          }).toList(),
    };
  }

  void restoreSearchDraft(Map<String, dynamic> draft) {
    if (draft.isEmpty) return;
    passengers = int.tryParse(draft['passengers']?.toString() ?? '') ?? 1;
    bookingTripLabel = draft['trip_label']?.toString() ?? bookingTripLabel;
    selectedPriorityType =
        draft['priority_type']?.toString() ?? selectedPriorityType;
    pets = draft['pets']?.toString() ?? '';
    specialBaggage = draft['special_baggage']?.toString() ?? '';
    preference = draft['preference']?.toString() ?? '';
    conciergeRequested = draft['concierge_requested'] == true;

    final rawRoutes = draft['routes'];
    if (rawRoutes is List && rawRoutes.isNotEmpty) {
      routes =
          rawRoutes.whereType<Map>().map((raw) {
            final row = Map<String, dynamic>.from(raw);
            return RouteModel(
              fromAirport: _findAirportByCode(row['origin']?.toString() ?? ''),
              toAirport: _findAirportByCode(
                row['destination']?.toString() ?? '',
              ),
              startDate: DateTime.tryParse(
                row['departure_datetime']?.toString() ?? '',
              ),
              endDate: DateTime.tryParse(row['end_datetime']?.toString() ?? ''),
              passengers:
                  int.tryParse(row['passengers']?.toString() ?? '') ??
                  passengers,
            );
          }).toList();
    }

    final aircraftId = draft['selected_aircraft_id']?.toString() ?? '';
    selectedAircraft =
        aircraftId.isEmpty
            ? null
            : aircraftFleet.cast<Aircraft?>().firstWhere(
              (item) => item?.id == aircraftId,
              orElse: () => null,
            );
    notifyListeners();
  }

  Airport? _findAirportByCode(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    for (final airport in airports) {
      if ((airport.icao ?? '').trim().toUpperCase() == normalized ||
          (airport.iata ?? '').trim().toUpperCase() == normalized) {
        return airport;
      }
    }
    return null;
  }

  void resetRoutes() {
    routes = [RouteModel()];
    notifyListeners();
  }

  void resetForm() {
    flightType = null;
    routeType = 'NACIONAL';
    bookingTripLabel = 'Solo ida';
    selectedPriorityType = 'essential';
    selectedAircraft = null;
    passengers = 1;
    startDate = null;
    endDate = null;
    fullName = '';
    email = '';
    phone = '';
    pets = '';
    specialBaggage = '';
    preference = '';
    conciergeRequested = false;
    paymentMethod = null;
    paymentNumber = null;
    bankName = null;
    clabe = null;
    cuenta = null;
    quoteMatches = [];
    selectedQuoteMatch = null;
    quoteError = null;
    quoteEmptyMessage = null;
    quotePreviewState = QuotePreviewState.idle;
    _lastQuotedLegs = const [];
    _lastQuotedPassengers = 1;
    _lastQuotedTripTypeCode = 'one_way';
    _lastQuotedTripTypeLabel = 'Ida';
    routes = [RouteModel()];
    notifyListeners();
  }

  void setPaymentMethod(String? method) {
    paymentMethod = method;

    if (method == 'WIRE') {
      if (language == 'ES') {
        bankName = 'BBVA Mexico';
        clabe = '012441001238761521';
        cuenta = '00744677210123876152';
      } else {
        bankName = 'Column N.A.';
        clabe = '121145433';
        cuenta = '749701713990491';
      }

      paymentNumber = null;
    }

    notifyListeners();
  }
}
