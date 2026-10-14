import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../models/aeropuerto.dart';
import '../../models/modelo_ruta.dart';
import '../../utils/maps/coordinate_validator.dart';

class ItineraryAirportPoint {
  const ItineraryAirportPoint({
    required this.identity,
    required this.code,
    required this.label,
    required this.position,
  });

  final String identity;
  final String code;
  final String label;
  final LatLng position;
}

class ItineraryMapLeg {
  const ItineraryMapLeg({
    required this.index,
    required this.origin,
    required this.destination,
    required this.points,
    required this.isReverseDuplicate,
  });

  final int index;
  final ItineraryAirportPoint origin;
  final ItineraryAirportPoint destination;
  final List<LatLng> points;
  final bool isReverseDuplicate;
}

class ItineraryMapData {
  const ItineraryMapData({
    required this.airports,
    required this.legs,
    required this.invalidLegCount,
  });

  final List<ItineraryAirportPoint> airports;
  final List<ItineraryMapLeg> legs;
  final int invalidLegCount;

  List<LatLng> get allPositions =>
      airports.map((airport) => airport.position).toList(growable: false);

  bool get hasGeometry => airports.isNotEmpty;

  static ItineraryMapData fromRoutes(
    List<RouteModel> routes, {
    List<Airport> airportCatalog = const [],
  }) {
    final airportsByIdentity = <String, ItineraryAirportPoint>{};
    final legs = <ItineraryMapLeg>[];
    final segmentKeys = <String>{};
    var invalidLegCount = 0;

    for (var index = 0; index < routes.length; index++) {
      final route = routes[index];
      final originResolution = _resolveAirport(
        route.fromAirport,
        airportCatalog,
      );
      final destinationResolution = _resolveAirport(
        route.toAirport,
        airportCatalog,
      );
      _logResolution(index, 'origen', route.fromAirport, originResolution);
      _logResolution(index, 'destino', route.toAirport, destinationResolution);
      final origin = originResolution.point;
      final destination = destinationResolution.point;
      if (origin == null || destination == null) {
        if (route.fromAirport != null || route.toAirport != null) {
          invalidLegCount++;
        }
        continue;
      }

      airportsByIdentity.putIfAbsent(origin.identity, () => origin);
      airportsByIdentity.putIfAbsent(destination.identity, () => destination);

      final directKey = '${origin.identity}>${destination.identity}';
      final reverseKey = '${destination.identity}>${origin.identity}';
      final isReverseDuplicate = segmentKeys.contains(reverseKey);
      segmentKeys.add(directKey);

      legs.add(
        ItineraryMapLeg(
          index: index,
          origin: origin,
          destination: destination,
          points: _visualLegPoints(
            origin.position,
            destination.position,
            index,
            separateReverse: isReverseDuplicate,
          ),
          isReverseDuplicate: isReverseDuplicate,
        ),
      );
    }

    return ItineraryMapData(
      airports: airportsByIdentity.values.toList(growable: false),
      legs: legs,
      invalidLegCount: invalidLegCount,
    );
  }

  static _AirportResolution _resolveAirport(
    Airport? selected,
    List<Airport> airportCatalog,
  ) {
    if (selected == null) {
      return const _AirportResolution(
        point: null,
        airport: null,
        source: 'sin aeropuerto seleccionado',
        validation: 'aeropuerto ausente',
      );
    }

    final selectedValidation = _validateAirport(selected);
    if (selectedValidation.isValid) {
      return _AirportResolution(
        point: _pointFromValidatedAirport(
          selected,
          selectedValidation,
          identity: _catalogIdentity(selected, airportCatalog),
        ),
        airport: selected,
        source: 'ruta',
        validation: 'valida',
      );
    }

    for (final candidates in [
      _matchingAirportsById(selected, airportCatalog),
      _matchingAirportsByCode(
        selected.icao,
        (airport) => airport.icao,
        airportCatalog,
      ),
      _matchingAirportsByCode(
        selected.iata,
        (airport) => airport.iata,
        airportCatalog,
      ),
    ]) {
      if (candidates.length != 1) continue;
      final candidate = candidates.single;
      final validation = _validateAirport(candidate);
      if (!validation.isValid) continue;
      return _AirportResolution(
        point: _pointFromValidatedAirport(candidate, validation),
        airport: candidate,
        source: 'catalogo',
        validation: 'valida',
      );
    }

    return _AirportResolution(
      point: null,
      airport: null,
      source: 'sin coincidencia confiable',
      validation: selectedValidation.reason ?? 'coordenadas invalidas',
    );
  }

  static List<Airport> _matchingAirportsById(
    Airport selected,
    List<Airport> catalog,
  ) {
    final id = selected.id;
    if (id == null || id <= 0) return const [];
    return catalog.where((airport) => airport.id == id).toList();
  }

  static List<Airport> _matchingAirportsByCode(
    String? selectedCode,
    String? Function(Airport airport) codeSelector,
    List<Airport> catalog,
  ) {
    final normalizedCode = _usableCode(selectedCode);
    if (normalizedCode == null) return const [];
    return catalog
        .where(
          (airport) => _usableCode(codeSelector(airport)) == normalizedCode,
        )
        .toList();
  }

  static String? _usableCode(String? value) {
    final normalized = value?.trim().toUpperCase() ?? '';
    if (normalized.isEmpty || normalized == r'\N') return null;
    return normalized;
  }

  static CoordinateValidationResult _validateAirport(Airport airport) {
    if (!airport.hasCoordinateValues) {
      return CoordinateValidationResult.invalid('coordenadas ausentes');
    }
    return CoordinateValidator.validate(
      latitude: airport.lat,
      longitude: airport.lng,
      rejectZeroZeroWhenSourceMissing: airport.lat == 0 && airport.lng == 0,
    );
  }

  static String _catalogIdentity(
    Airport selected,
    List<Airport> airportCatalog,
  ) {
    if (selected.id != null && selected.id! > 0) {
      final matches = _matchingAirportsById(selected, airportCatalog);
      if (matches.length == 1) return _identity(matches.single);
      return _identity(selected);
    }

    final icaoMatches = _matchingAirportsByCode(
      selected.icao,
      (airport) => airport.icao,
      airportCatalog,
    );
    if (icaoMatches.length == 1) return _identity(icaoMatches.single);

    final iataMatches = _matchingAirportsByCode(
      selected.iata,
      (airport) => airport.iata,
      airportCatalog,
    );
    if (iataMatches.length == 1) return _identity(iataMatches.single);
    return _identity(selected);
  }

  static ItineraryAirportPoint _pointFromValidatedAirport(
    Airport airport,
    CoordinateValidationResult validation, {
    String? identity,
  }) {
    return ItineraryAirportPoint(
      identity: identity ?? _identity(airport),
      code: airportDisplayCode(airport),
      label: _label(airport),
      position: LatLng(validation.latitude!, validation.longitude!),
    );
  }

  static void _logResolution(
    int index,
    String endpoint,
    Airport? selected,
    _AirportResolution resolution,
  ) {
    if (!kDebugMode) return;
    debugPrint(
      '[ItineraryMap] tramo ${index + 1} $endpoint: '
      'seleccionado=${_airportDebugData(selected)}; '
      'origen=${resolution.source}; '
      'resuelto=${_airportDebugData(resolution.airport)}; '
      'validacion=${resolution.validation}',
    );
  }

  static String _airportDebugData(Airport? airport) {
    if (airport == null) return 'ausente';
    return 'id=${airport.id}, iata=${airport.iata}, icao=${airport.icao}, '
        'lat=${airport.lat}, lng=${airport.lng}';
  }

  static String airportDisplayCode(Airport airport) {
    final iata = airport.iata?.trim().toUpperCase() ?? '';
    if (iata.isNotEmpty && iata != r'\N') return iata;
    final icao = airport.icao?.trim().toUpperCase() ?? '';
    if (icao.isNotEmpty && icao != r'\N') return icao;
    final name = airport.name.trim();
    if (name.isEmpty) return '---';
    return name.length <= 4
        ? name.toUpperCase()
        : name.substring(0, 4).toUpperCase();
  }

  static String _label(Airport airport) {
    final code = airportDisplayCode(airport);
    final city = airport.city.trim();
    final name = airport.name.trim();
    if (city.isNotEmpty) return '$code · $city';
    if (name.isNotEmpty) return '$code · $name';
    return code;
  }

  static String _identity(Airport airport) {
    if (airport.id != null) return 'id:${airport.id}';
    final icao = airport.icao?.trim().toUpperCase() ?? '';
    if (icao.isNotEmpty && icao != r'\N') return 'icao:$icao';
    final iata = airport.iata?.trim().toUpperCase() ?? '';
    if (iata.isNotEmpty && iata != r'\N') return 'iata:$iata';
    return 'geo:${airport.lat.toStringAsFixed(6)},${airport.lng.toStringAsFixed(6)}:${airport.name.trim().toUpperCase()}';
  }

  static List<LatLng> _visualLegPoints(
    LatLng from,
    LatLng to,
    int index, {
    required bool separateReverse,
  }) {
    final samePoint =
        from.latitude == to.latitude && from.longitude == to.longitude;
    if (samePoint) return [from, to];

    final offset = separateReverse || index.isEven ? 0.08 : -0.08;
    final midLat = (from.latitude + to.latitude) / 2;
    final midLng = (from.longitude + to.longitude) / 2;
    final dLat = to.latitude - from.latitude;
    final dLng = to.longitude - from.longitude;
    final length = dLat.abs() + dLng.abs();
    if (length == 0) return [from, to];

    final control = LatLng(
      midLat + (-dLng / length) * offset,
      midLng + (dLat / length) * offset,
    );
    return [from, control, to];
  }
}

class _AirportResolution {
  const _AirportResolution({
    required this.point,
    required this.airport,
    required this.source,
    required this.validation,
  });

  final ItineraryAirportPoint? point;
  final Airport? airport;
  final String source;
  final String validation;
}

@visibleForTesting
ItineraryMapData buildItineraryMapDataForTest(
  List<RouteModel> routes, {
  List<Airport> airportCatalog = const [],
}) {
  return ItineraryMapData.fromRoutes(routes, airportCatalog: airportCatalog);
}
