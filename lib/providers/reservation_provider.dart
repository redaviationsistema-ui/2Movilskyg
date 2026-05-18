import 'dart:io';

import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../models/aircraft.dart';
import '../models/airport.dart';
import '../models/route_model.dart';
import '../services/local_cache_service.dart';

class ReservationProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;
  final LocalCacheService _cacheService = LocalCacheService();

  String? flightType;
  String? aircraftType;

  String? paymentMethod;
  String? paymentNumber;
  String? bankName;
  String? clabe;
  String? cuenta;

  String language = 'ES';
  String routeType = 'NACIONAL';

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

      final tripType = routes.length > 1 ? 'multi_leg' : 'one_way';
      final requirements =
          routes
              .skip(1)
              .map((route) {
                return {
                  'origin':
                      route.fromAirport?.iata ?? route.fromAirport?.name ?? '',
                  'destination':
                      route.toAirport?.iata ?? route.toAirport?.name ?? '',
                  'date':
                      (route.startDate ?? startDate)
                          ?.toIso8601String()
                          .split('T')
                          .first,
                  'time': '09:00',
                  'passengers': route.passengers,
                };
              })
              .where((route) {
                return (route['origin'] as String).isNotEmpty &&
                    (route['destination'] as String).isNotEmpty;
              })
              .toList();

      final response = await _api.previewClientQuotes(
        origin: origin,
        destination: destination,
        departure: departure,
        passengers: passengers,
        tripType: tripType,
        aircraftType: flightType ?? aircraftType,
        requirements: requirements,
        notes:
            'App movil Red Sky. Pasajero: ${fullName.isEmpty ? 'pendiente' : fullName}.',
      );

      quoteMatches = _extractQuoteMatches(response);
      selectedQuoteMatch = _pickSelectedQuoteMatch(quoteMatches);

      if (quoteMatches.isEmpty) {
        quoteError = 'No se encontraron opciones para la ruta solicitada.';
        return false;
      }

      return true;
    } catch (error) {
      quoteError = 'No fue posible obtener una cotizacion real: $error';
      return false;
    } finally {
      isLoadingQuotePreview = false;
      notifyListeners();
    }
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

  void addRoute() {
    if (routes.isEmpty) {
      routes.add(RouteModel());
      notifyListeners();
      return;
    }

    final lastRoute = routes.last;

    if (lastRoute.toAirport == null) {
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

  void resetRoutes() {
    routes = [RouteModel()];
    notifyListeners();
  }

  void resetForm() {
    flightType = null;
    routeType = 'NACIONAL';
    selectedAircraft = null;
    passengers = 1;
    startDate = null;
    endDate = null;
    fullName = '';
    email = '';
    phone = '';
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
