import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/cliente_api.dart';
import '../models/aeronave.dart';
import '../models/aeropuerto.dart';
import '../models/modelo_ruta.dart';
import '../services/servicio_memoria_local.dart';
import '../utils/calculadora_precio.dart';

class ReservationProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;
  final LocalCacheService _cacheService = LocalCacheService();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_MX',
    symbol: 'USD ',
    decimalDigits: 0,
  );

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
  DateTime? lastSyncAt;
  DateTime? lastWorkspaceSyncAt;

  Aircraft? selectedAircraft;

  List<Aircraft> aircraftFleet = [];
  List<Map<String, dynamic>> flightRequests = [];
  List<Map<String, dynamic>> quoteMatches = [];
  Map<String, dynamic>? dashboardData;
  Map<String, dynamic>? selectedQuoteMatch;

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

  static const Map<String, String> priorityLabels = {
    'empty_leg': 'Empty Leg',
    'essential': 'Essential',
    'business': 'Business',
    'elite': 'Elite',
  };

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
    isLoadingData = true;
    syncMessage = 'Sincronizando informacion con el servidor...';
    notifyListeners();

    try {
      final hasInternet = await checkInternetConnection();
      if (!hasInternet) {
        await loadCachedData(fallbackReason: 'no_internet');
        return;
      }

      final normalizedAirports = (await _api.getAirports()).map(
        _normalizeAirport,
      );

      airports = normalizedAirports.map(Airport.fromJson).toList();

      final aircraftResponse = await _api.getAircraftPreview();
      aircraftFleet =
          aircraftResponse
              .map((json) => Aircraft.fromJson(Map<String, dynamic>.from(json)))
              .toList();

      final remoteReservations = await _fetchReservationsRemote();
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
      syncMessage =
          'Sincronizacion completada: ${airports.length} aeropuertos, ${aircraftFleet.length} aeronaves y ${reservations.length} reservas guardadas en el telefono.';
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

    isLoadingWorkspace = true;
    workspaceMessage = null;
    notifyListeners();

    try {
      await loadInitialData();

      if (!_api.hasToken) {
        workspaceMessage = 'Inicia sesion para ver informacion privada.';
        return;
      }

      final dashboardResponse = await _api.getClientDashboard();
      dashboardData = Map<String, dynamic>.from(dashboardResponse);

      final requests = await _api.getClientFlightRequests();
      flightRequests = requests;

      final originHint =
          routes.first.fromAirport?.iata ??
          routes.first.fromAirport?.name ??
          '';
      final liveAircraft = await _api.getClientAircraft(
        origin: originHint,
        passengers: passengers,
      );

      if (liveAircraft.isNotEmpty) {
        aircraftFleet =
            liveAircraft
                .map(
                  (json) => Aircraft.fromJson(Map<String, dynamic>.from(json)),
                )
                .toList();
      }

      lastWorkspaceSyncAt = DateTime.now();
      workspaceMessage =
          'Cabina sincronizada con ${flightRequests.length} solicitudes y ${aircraftFleet.length} aeronaves.';
    } catch (error) {
      workspaceMessage = 'No fue posible sincronizar la cabina: $error';
    } finally {
      isLoadingWorkspace = false;
      notifyListeners();
    }
  }

  Future<bool> previewCurrentSelection() async {
    quoteError = null;
    isLoadingQuotePreview = true;
    notifyListeners();

    try {
      final primaryRoute = routes.first;
      final origin =
          primaryRoute.fromAirport?.iata ??
          primaryRoute.fromAirport?.name ??
          '';
      final destination =
          primaryRoute.toAirport?.iata ?? primaryRoute.toAirport?.name ?? '';
      final departure = startDate ?? primaryRoute.startDate;

      if (origin.isEmpty || destination.isEmpty || departure == null) {
        quoteError = 'Completa origen, destino y fecha para cotizar.';
        return false;
      }

      final segmentCount = routes.length;
      final previewPayload = _buildBackendFlightRequestPayload();

      debugPrint('[client-quote][request] $previewPayload');

      final response = await _api.previewClientQuotesPayload(previewPayload);

      final prettyResponse = const JsonEncoder.withIndent(
        '  ',
      ).convert(response);
      debugPrint('[client-quote][raw-backend-response][start]');
      debugPrint(prettyResponse);
      debugPrint('[client-quote][raw-backend-response][end]');

      final responseMatches = _extractQuoteMatches(response);
      debugPrint('[client-quote][response] keys=${response.keys.toList()}');
      debugPrint(
        '[client-quote][response] matches=${responseMatches.length} segment_count=${response['segment_count']} trip_type=${response['trip_type']}',
      );
      if (responseMatches.isNotEmpty) {
        final sample = responseMatches.first;
        debugPrint(
          '[client-quote][sample] aircraft=${sample['aircraft_name'] ?? sample['aircraft']} aircraft_id=${sample['aircraft_id']} provider_id=${_nestedMap(sample['provider'])['id'] ?? sample['provider_id']} total=${sample['total'] ?? sample['final_price']} source_origin=${sample['source_origin']}',
        );
      }

      final catalog = await _api.getClientAircraft(
        origin: origin,
        passengers: passengers,
      );

      quoteMatches = _normalizeMatches(
        response,
        segmentCount: segmentCount,
        catalog: catalog,
      );
      quoteMatches = _filterMatchesForOrigin(
        quoteMatches,
        primaryRoute.fromAirport,
      );
      if (quoteMatches.isEmpty) {
        quoteMatches = _buildCatalogFallbackQuotes(catalog);
      }

      selectedQuoteMatch = _pickSelectedQuoteMatch(quoteMatches);

      debugPrint(
        '[client-quote][normalized] matches=${quoteMatches.length} selected=${selectedQuoteMatch?['aircraft'] ?? selectedQuoteMatch?['aircraft_name']}',
      );

      if (quoteMatches.isEmpty) {
        quoteError =
            'No hay operadores activos con match para esta ruta en este momento.';
        return false;
      }

      return true;
    } catch (error) {
      debugPrint('[client-quote][error] $error');
      quoteError = 'No fue posible obtener una cotizacion real: $error';
      return false;
    } finally {
      isLoadingQuotePreview = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createFlightRequestForMatch(
    Map<String, dynamic> quote,
  ) async {
    final primaryRoute = routes.first;
    final origin =
        primaryRoute.fromAirport?.iata ?? primaryRoute.fromAirport?.name ?? '';
    final destination =
        primaryRoute.toAirport?.iata ?? primaryRoute.toAirport?.name ?? '';
    final departure = startDate ?? primaryRoute.startDate;

    if (origin.isEmpty || destination.isEmpty || departure == null) {
      throw StateError('Faltan datos base para crear la solicitud.');
    }

    final response = await _api.createFlightRequestPayload(
      _buildBackendFlightRequestPayload(quote: quote),
    );

    return response;
  }

  Map<String, dynamic> _buildBackendFlightRequestPayload({
    Map<String, dynamic>? quote,
  }) {
    final normalizedLegs = _normalizedBackendLegs();
    final firstLeg = normalizedLegs.isNotEmpty ? normalizedLegs.first : null;
    final lastLeg = normalizedLegs.isNotEmpty ? normalizedLegs.last : null;
    final inferredClosedRoute =
        normalizedLegs.length > 1 &&
        (firstLeg?['origin']?.toString().trim().toUpperCase() ?? '') ==
            (lastLeg?['destination']?.toString().trim().toUpperCase() ?? '');
    final tripType =
        currentTripTypeCode != 'one_way'
            ? currentTripTypeCode
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
    final selectedAircraftModel =
        (quote?['aircraft'] ??
                quote?['aircraft_name'] ??
                quote?['model'] ??
                quote?['registration'] ??
                preference)
            ?.toString()
            .trim() ??
        '';
    final pricingBreakdown = _nestedMap(
      quote?['pricing_breakdown'] ??
          quote?['pricing_context'] ??
          quote?['pricing'],
    );
    final total = _asNumber(
      quote?['selected_card_price'] ??
          quote?['total'] ??
          quote?['final_price'] ??
          pricingBreakdown['total'] ??
          pricingBreakdown['final_price'],
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

    return {
      'origin': firstLeg?['origin'] ?? '',
      'base_airport': firstLeg?['origin'] ?? '',
      'destination': firstLeg?['destination'] ?? '',
      'departure_datetime': departureDatetime,
      'return_datetime': returnDatetime,
      'passengers': passengers,
      'trip_type': tripType,
      'trip_label': currentTripTypeLabel,
      'return_to_origin':
          tripType == 'multi_leg' ? shouldCloseRoute : inferredClosedRoute,
      'return_to_start':
          tripType == 'multi_leg' ? shouldCloseRoute : inferredClosedRoute,
      'close_route':
          tripType == 'multi_leg' ? shouldCloseRoute : inferredClosedRoute,
      'open_route': tripType == 'multi_leg' ? !shouldCloseRoute : false,
      'aircraft_type':
          selectedAircraftModel.isNotEmpty
              ? selectedAircraftModel
              : (flightType ?? aircraftType),
      'aircraft_model':
          selectedAircraftModel.isEmpty ? null : selectedAircraftModel,
      'assigned_aircraft_model':
          selectedAircraftModel.isEmpty ? null : selectedAircraftModel,
      'aircraft_name':
          selectedAircraftModel.isEmpty ? null : selectedAircraftModel,
      'aircraft_id': quote?['aircraft_id'],
      'provider_id': quote?['provider_id'],
      'match_id':
          quote?['match_id'] ?? quote?['matched_option_id'] ?? quote?['id'],
      'matched_option_id':
          quote?['matched_option_id'] ?? quote?['match_id'] ?? quote?['id'],
      'flight_package': selectedPriorityLabel,
      'service_tier': selectedPriorityLabel,
      'priority_type': selectedPriorityType,
      'priority_multiplier': priorityMultiplier,
      'priority_price': priorityPrice == 0 ? null : priorityPrice,
      'base_price': basePrice == 0 ? null : basePrice,
      'operational_fee':
          _asNumber(
                    quote?['operational_fee'] ??
                        pricingBreakdown['operational_fee'],
                  ) ==
                  0
              ? null
              : _asNumber(
                quote?['operational_fee'] ??
                    pricingBreakdown['operational_fee'],
              ),
      'subtotal': subtotal == 0 ? null : subtotal,
      'estimated_total': total == 0 ? null : total,
      'total': total == 0 ? null : total,
      'final_price': total == 0 ? null : total,
      'selected_card_price': total == 0 ? null : total,
      'time_display_mode': quote?['time_display_mode'] ?? 'direct',
      'billing_hours_mode': quote?['billing_hours_mode'] ?? 'operational',
      'flight_base_source': quote?['flight_base_source'] ?? 'billable_hours',
      'include_repositioning_in_billed_hours':
          quote?['include_repositioning_in_billed_hours'] ?? true,
      'include_return_to_base_in_billed_hours':
          quote?['include_return_to_base_in_billed_hours'] ?? true,
      'include_overnight_in_billed_hours':
          quote?['include_overnight_in_billed_hours'] ?? false,
      'pricing_context': pricingBreakdown.isEmpty ? null : pricingBreakdown,
      'pricing_formula_version':
          pricingBreakdown['pricing_formula_version'] ??
          quote?['pricing_formula_version'],
      'commercial_margin':
          pricingBreakdown['commercial_margin'] ?? quote?['commercial_margin'],
      'priority_factor':
          pricingBreakdown['priority_factor'] ?? quote?['priority_factor'],
      'billable_hours':
          pricingBreakdown['billable_hours'] ??
          pricingBreakdown['billableHours'] ??
          quote?['billable_hours'],
      'real_flight_hours':
          pricingBreakdown['real_flight_hours'] ?? quote?['real_flight_hours'],
      'minimum_hours':
          pricingBreakdown['minimum_hours'] ?? quote?['minimum_hours'],
      'minimum_route_price':
          pricingBreakdown['minimum_route_price'] ??
          quote?['minimum_route_price'],
      'subtotal_before_multipliers':
          pricingBreakdown['subtotal_before_multipliers'] ??
          quote?['subtotal_before_multipliers'] ??
          subtotal,
      'extra_services_total':
          pricingBreakdown['extra_services_total'] ??
          quote?['extra_services_total'],
      'source_database': quote?['source_database'],
      'source_table': quote?['source_table'],
      'aircraft_snapshot':
          quote == null
              ? null
              : {
                ...quote,
                'aircraft': selectedAircraftModel,
                'model': quote['model'] ?? selectedAircraftModel,
                'category': quote['cabin'] ?? quote['category'] ?? '',
                'capacity': quote['capacity'] ?? '',
                'selected_card_price': total == 0 ? null : total,
                'total': total == 0 ? null : total,
                'final_price': total == 0 ? null : total,
                'estimated_total': total == 0 ? null : total,
              },
      'requirements':
          normalizedLegs.length > 1
              ? (inferredClosedRoute && tripType == 'multi_leg'
                  ? normalizedLegs.sublist(1, normalizedLegs.length - 1)
                  : normalizedLegs.sublist(1))
              : [],
      'legs': normalizedLegs,
      'pets': pets.trim().isEmpty ? null : pets.trim(),
      'special_baggage':
          specialBaggage.trim().isEmpty ? null : specialBaggage.trim(),
      'preference':
          preference.trim().isEmpty ? selectedAircraftModel : preference.trim(),
      'overnight_nights': days == 0 ? null : days,
      'days': days,
      'notes': [
        currentTripTypeLabel,
        selectedPriorityLabel,
        fullName.isEmpty ? 'App movil Red Sky' : 'Pasajero: $fullName',
        if (pets.trim().isNotEmpty) pets.trim(),
        if (specialBaggage.trim().isNotEmpty) specialBaggage.trim(),
        if (pricingBreakdown['minimum_route_price'] != null)
          'Minimo ruta ${pricingBreakdown['minimum_route_price']}',
        'Noches $days',
        if (subtotal > 0) 'Subtotal $subtotal',
        if (total > 0) 'Total $total',
      ].join(' | '),
    };
  }

  List<Map<String, dynamic>> _normalizedBackendLegs() {
    return routes
        .map((route) {
          final date = route.startDate ?? startDate;
          final dateLabel = date == null ? '' : _dateOnly(date);
          final timeLabel = date == null ? '09:00' : _timeOnly(date);

          return {
            'origin': route.fromAirport?.iata ?? route.fromAirport?.name ?? '',
            'destination': route.toAirport?.iata ?? route.toAirport?.name ?? '',
            'date': dateLabel,
            'time': timeLabel,
            'departure_datetime':
                dateLabel.isEmpty ? '' : '$dateLabel $timeLabel',
            'passengers': route.passengers > 0 ? route.passengers : passengers,
          };
        })
        .where((leg) {
          return (leg['origin'] as String).isNotEmpty &&
              (leg['destination'] as String).isNotEmpty;
        })
        .toList();
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
    required List<Map<String, dynamic>> catalog,
  }) {
    final rawMatches = _extractQuoteMatches(payload);
    final normalized =
        rawMatches
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

    return _mergeMatchesWithCatalog(normalized, catalog);
  }

  List<Map<String, dynamic>> _buildCatalogFallbackQuotes(
    List<Map<String, dynamic>> catalog,
  ) {
    if (catalog.isEmpty || routes.isEmpty) return [];

    final primaryRoute = routes.first;
    final filteredCatalog =
        catalog
            .asMap()
            .entries
            .map(
              (entry) => _normalizeCatalogAircraft(
                Map<String, dynamic>.from(entry.value),
                entry.key,
              ),
            )
            .where(_isActiveCatalogAircraft)
            .where((item) {
              final capacity = _asNumber(item['capacity']);
              return passengers <= 0 || capacity <= 0 || capacity >= passengers;
            })
            .map((item) {
              final baseMatches = _originMatches(
                item['source_origin']?.toString() ?? '',
                primaryRoute.fromAirport,
              );
              return {
                ...item,
                'queried_base_airport':
                    primaryRoute.fromAirport?.iata ??
                    primaryRoute.fromAirport?.name ??
                    '',
                'base_airport_match': baseMatches,
                'match_reason':
                    baseMatches
                        ? 'Coincide con base_airport ${item['source_origin']}'
                        : item['match_reason'] ??
                            (item['source_origin']?.toString().isNotEmpty ==
                                    true
                                ? 'Salida optimizada desde ${item['source_origin']}'
                                : 'Opcion verificada'),
              };
            })
            .toList();

    final exactBaseMatches =
        filteredCatalog
            .where((item) => item['base_airport_match'] == true)
            .toList();
    final candidates =
        primaryRoute.fromAirport != null && exactBaseMatches.isNotEmpty
            ? exactBaseMatches
            : filteredCatalog;

    final fallbackQuotes =
        candidates
            .map((item) {
              final aircraft = Aircraft.fromJson({
                'id': item['aircraft_id'] ?? item['id'],
                'name': item['aircraft'],
                'model': item['model'] ?? item['aircraft'],
                'aircraft_type': item['cabin'],
                'capacity': _asNumber(item['capacity']).round(),
                'hourly_rate': _asNumber(
                  item['hourly_rate'] ?? item['base_price'],
                ),
                'speed_kmh': _asNumber(item['speed_kmh'], 650),
                'base_airport': item['source_origin'],
                'city': item['source_origin'],
                'minimum_hours': _asNumber(item['minimum_hours'], 1),
                'crew_overnight_usd': _asNumber(item['overnight_fee']),
                'national_expenses_usd': _asNumber(
                  item['national_expenses_usd'] ?? item['operational_cost'],
                ),
                'international_expenses_usd': _asNumber(
                  item['international_expenses_usd'] ??
                      item['operational_cost'],
                ),
              });
              final pricing = PriceCalculator.calculate(
                aircraft: aircraft,
                route: primaryRoute,
                startDate: startDate ?? primaryRoute.startDate,
                endDate: endDate,
                international: routeType.toUpperCase().contains('INTER'),
              );
              final basePrice =
                  pricing.flightCost > 0
                      ? pricing.flightCost
                      : _asNumber(item['base_price'] ?? item['hourly_rate']);
              final operationalCost =
                  pricing.operationalCost +
                  pricing.overnightCost +
                  _asNumber(item['landing_fees']) +
                  _asNumber(item['fbo_fees']) +
                  _asNumber(item['expense_fee']);
              final total = basePrice + operationalCost;

              if (total <= 0) return null;

              return {
                ...item,
                'match_id':
                    item['match_id'] ?? 'catalog-${item['aircraft_id']}',
                'matched_option_id':
                    item['matched_option_id'] ??
                    'catalog-${item['aircraft_id']}',
                'base_price': double.parse(basePrice.toStringAsFixed(2)),
                'final_price': _asMoney(total),
                'total': double.parse(total.toStringAsFixed(2)),
                'subtotal': double.parse(basePrice.toStringAsFixed(2)),
                'priority_type': selectedPriorityType,
                'priority_multiplier': 1,
                'priority_price': 0,
                'operational_cost': double.parse(
                  operationalCost.toStringAsFixed(2),
                ),
                'overnight_fees': double.parse(
                  pricing.overnightCost.toStringAsFixed(2),
                ),
                'time':
                    item['time']?.toString().trim().isNotEmpty == true
                        ? item['time']
                        : _formatDurationFromHours(pricing.flightHours),
                'estimated_hours': pricing.flightHours,
                'billable_hours': pricing.hours,
                'real_flight_hours': pricing.flightHours,
                'distance_km': pricing.distanceKm,
                'distance_nm': pricing.distanceNm,
                'source_table':
                    item['source_table'] ?? 'catalog_fallback_quote',
                'pricing_breakdown': {
                  'source': 'catalog_fallback',
                  'billable_hours': pricing.hours,
                  'real_flight_hours': pricing.flightHours,
                  'base_price': double.parse(basePrice.toStringAsFixed(2)),
                  'overnight': double.parse(
                    pricing.overnightCost.toStringAsFixed(2),
                  ),
                  'operational': double.parse(
                    pricing.operationalCost.toStringAsFixed(2),
                  ),
                  'subtotal': double.parse(basePrice.toStringAsFixed(2)),
                  'total': double.parse(total.toStringAsFixed(2)),
                },
                'pricing_context': {
                  'pricing_formula_version': 'mobile-catalog-fallback-v1',
                  'billable_hours': pricing.hours,
                  'real_flight_hours': pricing.flightHours,
                  'base_cost': double.parse(basePrice.toStringAsFixed(2)),
                  'operational_costs_total': double.parse(
                    operationalCost.toStringAsFixed(2),
                  ),
                  'subtotal_before_multipliers': double.parse(
                    basePrice.toStringAsFixed(2),
                  ),
                  'total': double.parse(total.toStringAsFixed(2)),
                  'final_price': double.parse(total.toStringAsFixed(2)),
                  'selected_card_price': double.parse(total.toStringAsFixed(2)),
                },
              };
            })
            .whereType<Map<String, dynamic>>()
            .toList();

    fallbackQuotes.sort((first, second) {
      final firstBase = first['base_airport_match'] == true ? 0 : 1;
      final secondBase = second['base_airport_match'] == true ? 0 : 1;
      if (firstBase != secondBase) return firstBase.compareTo(secondBase);
      return _asNumber(
        first['base_price'],
        double.maxFinite,
      ).compareTo(_asNumber(second['base_price'], double.maxFinite));
    });

    return fallbackQuotes;
  }

  Map<String, dynamic> _normalizeCatalogAircraft(
    Map<String, dynamic> raw,
    int index,
  ) {
    final aircraftName =
        raw['model'] ??
        raw['name'] ??
        raw['aircraft_name'] ??
        raw['registration'] ??
        raw['matricula'] ??
        'Aeronave privada ${index + 1}';
    final images = _extractImages(raw, raw);
    final base =
        raw['source_origin'] ??
        raw['base_airport'] ??
        raw['base'] ??
        raw['base_airport_code'] ??
        raw['home_base'] ??
        raw['airport'] ??
        '';

    return {
      ...raw,
      'id': raw['id'] ?? 'aircraft-db-$index',
      'match_id': raw['match_id'],
      'matched_option_id': raw['matched_option_id'],
      'aircraft_id': raw['aircraft_id'] ?? raw['aircraftId'] ?? raw['id'],
      'provider_id': raw['provider_id'] ?? _nestedMap(raw['provider'])['id'],
      'aircraft': aircraftName,
      'cabin':
          raw['category'] ??
          raw['aircraft_category'] ??
          raw['type'] ??
          raw['cabin'] ??
          'Cabina verificada',
      'capacity': raw['capacity'] ?? raw['passenger_capacity'] ?? '',
      'model':
          raw['manufacturer'] != null
              ? [raw['manufacturer'], raw['registration'] ?? raw['matricula']]
                  .where(
                    (value) => value != null && value.toString().isNotEmpty,
                  )
                  .join(' | ')
              : raw['registration'] ?? raw['matricula'] ?? raw['model'] ?? '',
      'registration': raw['registration'] ?? raw['matricula'] ?? '',
      'hourly_rate': _resolveHourlyRate(raw),
      'base_price': _asNumber(
        raw['flight_base'] ??
            raw['base_price'] ??
            raw['final_price'] ??
            raw['price'] ??
            raw['quoted_price'] ??
            _resolveHourlyRate(raw),
      ),
      'minimum_hours': raw['minimum_hours'] ?? raw['min_hours'] ?? '',
      'speed_kmh': raw['speed_kmh'] ?? raw['speedKmh'] ?? '',
      'speed_knots': raw['speed_knots'] ?? raw['speedKnots'] ?? '',
      'landing_fees': _asNumber(raw['landing_fees'] ?? raw['landing_fee']),
      'fbo_fees': _asNumber(raw['fbo_fees'] ?? raw['fbo']),
      'expense_fee': _asNumber(raw['expense_fee'] ?? raw['airport_expenses']),
      'overnight_fee': _asNumber(raw['overnight_fee']),
      'status': raw['status'] ?? raw['aircraft_status'] ?? '',
      'image_url': images.isNotEmpty ? images.first['imageUrl'] : '',
      'images': images,
      'source_database':
          raw['source_database'] ?? raw['database'] ?? 'aircraft',
      'source_table': raw['source_table'] ?? raw['table'] ?? 'aircraft',
      'source_origin': base,
      'match_reason':
          base.toString().isNotEmpty
              ? 'Salida optimizada desde $base'
              : 'Opcion verificada',
    };
  }

  bool _isActiveCatalogAircraft(Map<String, dynamic> item) {
    final status = _normalizeLookup(item['status']).toLowerCase();
    return const {
      '',
      'active',
      'trial active',
      'approved',
      'aprobada',
      'available',
      'disponible',
    }.contains(status);
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
    final computedPricing = _buildPricingBreakdown(
      match,
      aircraftRecord,
      segmentCount: segmentCount,
    );
    final pricing =
        backendPricing ??
        (computedPricing['hasFormulaInputs'] == true ? computedPricing : null);
    final resolvedTotal =
        pricing != null
            ? _asNumber(pricing['total'])
            : _asNumber(
              match['final_price'] ??
                  match['total'] ??
                  match['price'] ??
                  match['quoted_price'],
            );

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
      'aircraft':
          match['aircraft_name'] ??
          match['name'] ??
          aircraftRecord['name'] ??
          aircraftRecord['model'] ??
          aircraftRecord['category'] ??
          'Aeronave verificada',
      'time':
          match['time'] ??
          match['flight_time'] ??
          match['duration'] ??
          'Tiempo por confirmar',
      'final_price':
          pricing != null
              ? _asMoney(pricing['total'])
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
      'match_reason':
          match['match_reason'] ??
          'Seleccion destacada por disponibilidad real.',
      'image_url': _primaryImage(match) ?? _primaryImage(aircraftRecord) ?? '',
      'images': _extractImages(match, aircraftRecord),
      'pricing_context':
          match['pricing_context'] ?? match['pricingContext'] ?? pricing,
      'pricing_breakdown': pricing,
      'total': pricing != null ? pricing['total'] : resolvedTotal,
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
    final rawBreakdown = _nestedMap(
      match['pricing_breakdown'] ??
          match['pricingBreakdown'] ??
          match['breakdown'] ??
          match['pricing'],
    );

    final source = rawBreakdown.isNotEmpty ? rawBreakdown : match;

    final billableHours = _asNumber(
      source['billable_hours'] ??
          source['billableHours'] ??
          source['estimated_hours'] ??
          source['flight_hours'],
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
      source['total'] ??
          source['final_price'] ??
          source['finalPrice'] ??
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
            source['ivaRate'],
        double.nan,
      ),
      'base_price': basePrice.isNaN ? 0 : basePrice,
      'hourly_rate': _asNumber(
        source['hourly_rate'] ?? source['hourlyRate'],
        0,
      ),
    };
  }

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

  List<Map<String, dynamic>> _mergeMatchesWithCatalog(
    List<Map<String, dynamic>> matches,
    List<Map<String, dynamic>> catalog,
  ) {
    if (catalog.isEmpty) return matches;

    return matches.map((match) {
      final catalogAircraft = _findMatchingCatalogAircraft(match, catalog);
      if (catalogAircraft == null) return match;

      return {
        ...match,
        'aircraft_id':
            match['aircraft_id'] ??
            catalogAircraft['aircraft_id'] ??
            catalogAircraft['id'],
        'provider_id':
            match['provider_id'] ??
            catalogAircraft['provider_id'] ??
            _nestedMap(catalogAircraft['provider'])['id'],
        'capacity': match['capacity'] ?? catalogAircraft['capacity'] ?? '',
        'model': match['model'] ?? catalogAircraft['model'] ?? '',
        'registration':
            match['registration'] ?? catalogAircraft['registration'] ?? '',
        'image_url':
            (_primaryImage(catalogAircraft) ?? match['image_url'] ?? '')
                .toString(),
        'images': _extractImages(catalogAircraft, const {}),
        'source_origin':
            catalogAircraft['source_origin'] ??
            catalogAircraft['base_airport'] ??
            match['source_origin'],
        'match_reason':
            catalogAircraft['source_origin'] != null
                ? 'Salida optimizada desde ${catalogAircraft['source_origin']}'
                : match['match_reason'],
      };
    }).toList();
  }

  List<Map<String, dynamic>> _filterMatchesForOrigin(
    List<Map<String, dynamic>> matches,
    Airport? originAirport,
  ) {
    if (matches.isEmpty || originAirport == null) return matches;

    final exactBaseMatches =
        matches.where((match) {
          final sourceOrigin = match['source_origin']?.toString() ?? '';
          return _originMatches(sourceOrigin, originAirport);
        }).toList();

    if (exactBaseMatches.isNotEmpty) {
      return exactBaseMatches;
    }

    return matches;
  }

  Map<String, dynamic>? _findMatchingCatalogAircraft(
    Map<String, dynamic> match,
    List<Map<String, dynamic>> catalog,
  ) {
    final matchValues = _aircraftLookupValues(match).toSet();
    if (matchValues.isEmpty) return null;

    for (final aircraft in catalog) {
      final aircraftValues = _aircraftLookupValues(aircraft);
      if (aircraftValues.any(matchValues.contains)) {
        return aircraft;
      }
    }

    return null;
  }

  List<String> _aircraftLookupValues(Map<String, dynamic> raw) {
    return [
          raw['aircraft_id'],
          raw['id'],
          raw['aircraft'],
          raw['model'],
          raw['registration'],
          raw['matricula'],
          raw['name'],
        ]
        .map((value) => _normalizeLookup(value))
        .where((value) => value.isNotEmpty)
        .toList();
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
            'origin': route.fromAirport?.iata ?? route.fromAirport?.name ?? '',
            'destination': route.toAirport?.iata ?? route.toAirport?.name ?? '',
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
            'origin': route.fromAirport?.iata ?? route.fromAirport?.name ?? '',
            'destination': route.toAirport?.iata ?? route.toAirport?.name ?? '',
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
      _normalizeLookup(originAirport.iata),
      _normalizeLookup(originAirport.city),
      _normalizeLookup(originAirport.name),
      _normalizeLookup('${originAirport.city} ${originAirport.iata ?? ''}'),
    }..remove('');

    return candidates.any(
      (candidate) => base.contains(candidate) || candidate.contains(base),
    );
  }

  String _formatDurationFromHours(double hours) {
    if (hours <= 0 || hours.isNaN || hours.isInfinite) return '';

    final totalMinutes = (hours * 60).round();
    final wholeHours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (wholeHours > 0 && minutes > 0) return '$wholeHours h $minutes m';
    if (wholeHours > 0) return '$wholeHours h';
    return '$minutes m';
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
    passengers = value;
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

    routes[index].passengers = value;
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
