import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../models/aircraft.dart';
import '../models/airport.dart';
import '../models/route_model.dart';
import '../services/local_cache_service.dart';

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

      final tripType = currentTripTypeCode;
      final segmentCount = routes.length;
      final requirements = buildRequirementsPayload();
      final legs = buildLegsPayload();
      final previewPayload = {
        'origin': origin,
        'destination': destination,
        'departure_datetime': departure.toIso8601String(),
        'passengers': passengers,
        'trip_type': tripType,
        'trip_label': currentTripTypeLabel,
        'aircraft_type': flightType ?? aircraftType,
        'flight_package': selectedPriorityLabel,
        'priority_type': selectedPriorityType,
        'preference': preference,
        'pets': pets,
        'special_baggage': specialBaggage,
        'legs': legs,
        'requirements': requirements,
        'notes':
            'App movil Red Sky. Pasajero: ${fullName.isEmpty ? 'pendiente' : fullName}.',
      };

      debugPrint('[client-quote][request] $previewPayload');

      final response = await _api.previewClientQuotes(
        origin: origin,
        destination: destination,
        departure: departure,
        passengers: passengers,
        tripType: tripType,
        tripLabel: currentTripTypeLabel,
        aircraftType: flightType ?? aircraftType,
        flightPackage: selectedPriorityLabel,
        priorityType: selectedPriorityType,
        preference: preference,
        pets: pets,
        specialBaggage: specialBaggage,
        legs: legs,
        requirements: requirements,
        notes:
            'App movil Red Sky. Pasajero: ${fullName.isEmpty ? 'pendiente' : fullName}.',
      );

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

    final pricingBreakdown =
        quote['pricing_breakdown'] is Map
            ? Map<String, dynamic>.from(quote['pricing_breakdown'] as Map)
            : <String, dynamic>{};
    final selectedAircraftModel =
        (quote['aircraft'] ??
                quote['aircraft_name'] ??
                quote['model'] ??
                quote['registration'] ??
                '')
            .toString();

    final response = await _api.createFlightRequest(
      origin: origin,
      destination: destination,
      departure: departure,
      passengers: passengers,
      tripType: currentTripTypeCode,
      tripLabel: currentTripTypeLabel,
      aircraftType: flightType ?? aircraftType,
      providerId: quote['provider_id']?.toString(),
      aircraftId: quote['aircraft_id']?.toString(),
      matchId: quote['match_id']?.toString() ?? quote['id']?.toString(),
      matchedOptionId:
          quote['matched_option_id']?.toString() ??
          quote['match_id']?.toString(),
      requirements: buildRequirementsPayload(),
      extraBody: {
        'legs': buildLegsPayload(),
        'pets': pets,
        'special_baggage': specialBaggage,
        'preference': preference,
        'flight_package': selectedPriorityLabel,
        'service_tier': selectedPriorityLabel,
        'priority_type': selectedPriorityType,
        'priority_multiplier': _asNumber(
          quote['priority_multiplier'] ??
              pricingBreakdown['priority_multiplier'],
          1,
        ),
        'priority_price': _asNumber(
          quote['priority_price'] ?? pricingBreakdown['priority_price'],
        ),
        'base_price': _asNumber(
          quote['base_price'] ?? pricingBreakdown['base_price'],
        ),
        'subtotal': _asNumber(
          quote['subtotal'] ?? pricingBreakdown['subtotal'],
        ),
        'total': _asNumber(quote['total'] ?? pricingBreakdown['total']),
        'final_price': _asNumber(
          quote['total'] ??
              quote['final_price'] ??
              pricingBreakdown['total'] ??
              pricingBreakdown['final_price'],
        ),
        'estimated_total': _asNumber(
          quote['total'] ??
              quote['final_price'] ??
              pricingBreakdown['total'] ??
              pricingBreakdown['final_price'],
        ),
        'billable_hours': _asNumber(
          pricingBreakdown['billable_hours'] ??
              pricingBreakdown['billableHours'],
        ),
        'aircraft_model': selectedAircraftModel,
        'assigned_aircraft_model': selectedAircraftModel,
        'aircraft_name': selectedAircraftModel,
        'aircraft_snapshot': {
          ...quote,
          'aircraft': selectedAircraftModel,
          'model': quote['model'] ?? selectedAircraftModel,
          'category': quote['cabin'] ?? quote['category'] ?? '',
          'capacity': quote['capacity'] ?? '',
          'registration': quote['registration'] ?? '',
        },
      },
      notes:
          'Solicitud creada desde app movil Red Sky para ${fullName.isEmpty ? 'cliente' : fullName}.',
    );

    return response;
  }

  List<Map<String, dynamic>> _extractQuoteMatches(
    Map<String, dynamic> payload,
  ) {
    final raw =
        payload['matches'] ??
        payload['options'] ??
        payload['results'] ??
        payload['data'];

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
    final rawPricing =
        backendPricing ??
        (computedPricing['hasFormulaInputs'] == true ? computedPricing : null);
    final pricing = _buildClientFacingPricing(
      match,
      aircraftRecord,
      rawPricing,
      segmentCount: segmentCount,
    );
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

  Map<String, dynamic>? _buildClientFacingPricing(
    Map<String, dynamic> match,
    Map<String, dynamic> aircraftRecord,
    Map<String, dynamic>? rawPricing, {
    required int segmentCount,
  }) {
    if (rawPricing == null) return null;

    final source =
        rawPricing['source'] == 'backend' ? rawPricing : {...rawPricing};
    final basePrice = _asNumber(
      source['base_price'] ??
          match['base_price'] ??
          aircraftRecord['base_price'] ??
          source['total'],
    );
    final billableHours = _asNumber(
      source['billable_hours'] ?? source['billableHours'],
    );
    final hourlyRate = _asNumber(
      source['hourly_rate'] ??
          source['hourlyRate'] ??
          match['hourly_rate'] ??
          aircraftRecord['hourly_rate'],
    );
    final normalizedBasePrice =
        basePrice > 0
            ? basePrice
            : (billableHours > 0 && hourlyRate > 0
                ? billableHours * hourlyRate
                : 0);

    final markupPercent = _resolveRedSkyMarkup(match, aircraftRecord, source);
    final markupAmount =
        normalizedBasePrice > 0
            ? normalizedBasePrice * (markupPercent / 100)
            : 0;

    final overnight = _asNumber(
      source['overnight'] ??
          source['overnight_fee'] ??
          source['overnightFee'] ??
          source['overnight_cost'] ??
          match['overnight_fees'] ??
          match['overnight_fee'],
    );

    final expenseFee = _asNumber(
      source['expense_fee'] ??
          source['expenseFee'] ??
          source['additionalOperationalCost'] ??
          match['expense_fee'],
    );

    final airportFees = _asNumber(
      source['airport_fees'] ??
          source['airportFees'] ??
          (source.containsKey('landing_fees') || source.containsKey('fbo_fees')
              ? _asNumber(source['landing_fees']) +
                  _asNumber(source['fbo_fees'])
              : double.nan),
      double.nan,
    );
    final normalizedAirportFees =
        airportFees.isNaN
            ? _asNumber(match['landing_fees']) + _asNumber(match['fbo_fees'])
            : airportFees;

    final subtotalBeforeTax =
        normalizedBasePrice +
        markupAmount +
        overnight +
        expenseFee +
        normalizedAirportFees;

    final taxRate = _asNumber(
      source['tax_rate'] ??
          source['taxRate'] ??
          source['iva_rate'] ??
          source['ivaRate'],
      double.nan,
    );
    final explicitTaxAmount = _asNumber(
      source['taxes'] ?? source['tax'] ?? match['taxes'] ?? match['tax'],
      double.nan,
    );
    final normalizedTaxAmount =
        !taxRate.isNaN
            ? subtotalBeforeTax * taxRate
            : (explicitTaxAmount.isNaN ? 0 : explicitTaxAmount);

    final total = subtotalBeforeTax + normalizedTaxAmount;

    return {
      ...source,
      'source': source['source'] ?? 'computed',
      'pricing_model': 'client_commercial',
      'segment_count': segmentCount,
      'billable_hours': billableHours > 0 ? billableHours : null,
      'billableHours': billableHours > 0 ? billableHours : null,
      'hourly_rate': hourlyRate,
      'base_price': double.parse(normalizedBasePrice.toStringAsFixed(2)),
      'backend_total_raw': _asNumber(source['total'], 0),
      'backend_subtotal_raw': _asNumber(source['subtotal'], 0),
      'redsky_markup_percent': double.parse(markupPercent.toStringAsFixed(2)),
      'redsky_markup_factor': double.parse(
        (1 + (markupPercent / 100)).toStringAsFixed(4),
      ),
      'markup': double.parse(markupAmount.toStringAsFixed(2)),
      'priority_price': double.parse(markupAmount.toStringAsFixed(2)),
      'overnight': double.parse(overnight.toStringAsFixed(2)),
      'overnight_cost': double.parse(overnight.toStringAsFixed(2)),
      'expense_fee': double.parse(expenseFee.toStringAsFixed(2)),
      'airport_fees': double.parse(normalizedAirportFees.toStringAsFixed(2)),
      'subtotal': double.parse(subtotalBeforeTax.toStringAsFixed(2)),
      'subtotal_before_multipliers': double.parse(
        subtotalBeforeTax.toStringAsFixed(2),
      ),
      'tax_rate':
          taxRate.isNaN ? null : double.parse(taxRate.toStringAsFixed(4)),
      'taxes': double.parse(normalizedTaxAmount.toStringAsFixed(2)),
      'tax': double.parse(normalizedTaxAmount.toStringAsFixed(2)),
      'utility': double.parse(markupAmount.toStringAsFixed(2)),
      'total': double.parse(total.toStringAsFixed(2)),
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

  double _resolveRedSkyMarkup(
    Map<String, dynamic> match,
    Map<String, dynamic> aircraftRecord,
    Map<String, dynamic> pricingSource,
  ) {
    return _asNumber(
      pricingSource['redsky_markup_percent'] ??
          match['redsky_markup_percent'] ??
          pricingSource['redsky_markup'] ??
          match['redsky_markup'] ??
          aircraftRecord['redsky_markup'] ??
          _nestedMap(match['aircraft'])['redsky_markup'] ??
          _nestedMap(aircraftRecord['aircraft'])['redsky_markup'],
      0,
    );
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
