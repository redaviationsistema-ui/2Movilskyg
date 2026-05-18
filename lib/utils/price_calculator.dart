import '../models/aircraft.dart';
import '../models/route_model.dart';
import 'distance_calculator.dart';

/// Encapsulates the commercial output of a charter quotation.
class PriceResult {
  final double distanceKm;
  final double distanceNm;
  final double flightHours;
  final double flightCost;
  final double overnightCost;
  final double operationalCost;

  /// Backward-compatible aliases used by the UI layer.
  final double miles;
  final double hours;

  const PriceResult({
    required this.distanceKm,
    required this.distanceNm,
    required this.flightHours,
    required this.flightCost,
    required this.overnightCost,
    required this.operationalCost,
    required this.miles,
    required this.hours,
  });

  const PriceResult.zero()
    : distanceKm = 0,
      distanceNm = 0,
      flightHours = 0,
      flightCost = 0,
      overnightCost = 0,
      operationalCost = 0,
      miles = 0,
      hours = 0;
}

/// Calculates charter pricing using routed distance, block time and trip fees.
class PriceCalculator {
  static const double _kmPerNauticalMile = 1.852;
  static const double _domesticRoutingFactor = 1.12;
  static const double _internationalRoutingFactor = 1.15;
  static const double _defaultMinimumBillableHours = 1.25;
  static const double _overnightRateFactor = 0.5;

  static double round(double value) => double.parse(value.toStringAsFixed(2));

  /// Rounds billable time up to the next quarter hour.
  static double roundQuarter(double hours) {
    return (hours * 4).ceil() / 4;
  }

  static PriceResult calculate({
    required Aircraft aircraft,
    required RouteModel route,
    DateTime? startDate,
    DateTime? endDate,
    bool international = false,
  }) {
    if (!_hasValidRoute(route) || !_hasValidAircraft(aircraft)) {
      return const PriceResult.zero();
    }

    final departureAirport = route.fromAirport!;
    final arrivalAirport = route.toAirport!;

    final greatCircleDistanceKm = DistanceCalculator.distanceKm(
      departureAirport.lat,
      departureAirport.lng,
      arrivalAirport.lat,
      arrivalAirport.lng,
    );

    final routedDistanceNm = _calculateRoutedDistanceNm(
      greatCircleDistanceKm: greatCircleDistanceKm,
      international: international,
    );

    final blockHours = _calculateBillableFlightHours(
      distanceNm: routedDistanceNm,
      cruiseSpeedKnots: aircraft.cruiseSpeedKnots,
      minimumBillableHours: aircraft.minimumHours,
    );

    final flightCost = round(aircraft.rentalPriceUsd * blockHours);
    final overnightCost = _calculateOvernightCost(
      hourlyRateUsd: aircraft.rentalPriceUsd,
      crewOvernightUsd: aircraft.crewOvernightUsd,
      startDate: startDate,
      endDate: endDate,
    );
    final operationalCost =
        international
            ? aircraft.internationalExpensesUsd
            : aircraft.nationalExpensesUsd;

    final roundedDistanceKm = round(greatCircleDistanceKm);
    final roundedDistanceNm = round(routedDistanceNm);

    return PriceResult(
      distanceKm: roundedDistanceKm,
      distanceNm: roundedDistanceNm,
      flightHours: blockHours,
      flightCost: flightCost,
      overnightCost: overnightCost,
      operationalCost: operationalCost,
      miles: roundedDistanceNm,
      hours: blockHours,
    );
  }

  static bool _hasValidRoute(RouteModel route) {
    return route.fromAirport != null && route.toAirport != null;
  }

  static bool _hasValidAircraft(Aircraft aircraft) {
    return aircraft.cruiseSpeedKnots > 0 && aircraft.rentalPriceUsd > 0;
  }

  /// Converts great-circle distance to a practical routed distance.
  static double _calculateRoutedDistanceNm({
    required double greatCircleDistanceKm,
    required bool international,
  }) {
    final routingFactor =
        international ? _internationalRoutingFactor : _domesticRoutingFactor;
    final routedDistanceKm = greatCircleDistanceKm * routingFactor;
    return routedDistanceKm / _kmPerNauticalMile;
  }

  /// Applies a stage-length block buffer and the aircraft's minimum charge.
  static double _calculateBillableFlightHours({
    required double distanceNm,
    required double cruiseSpeedKnots,
    required double minimumBillableHours,
  }) {
    final airborneHours = distanceNm / cruiseSpeedKnots;
    final blockHours = airborneHours + _blockBufferForStageLength(distanceNm);
    final roundedBlockHours = roundQuarter(blockHours);
    final minimumCharge =
        minimumBillableHours > 0
            ? minimumBillableHours
            : _defaultMinimumBillableHours;

    return roundedBlockHours < minimumCharge
        ? minimumCharge
        : roundedBlockHours;
  }

  /// Taxi, ATC and handling allowance by trip stage length.
  static double _blockBufferForStageLength(double distanceNm) {
    if (distanceNm < 300) return 0.25;
    if (distanceNm < 600) return 0.35;
    if (distanceNm < 1000) return 0.45;
    return 0.5;
  }

  static double _calculateOvernightCost({
    required double hourlyRateUsd,
    required double crewOvernightUsd,
    required DateTime? startDate,
    required DateTime? endDate,
  }) {
    if (startDate == null || endDate == null) {
      return 0;
    }

    final departureDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final returnDate = DateTime(endDate.year, endDate.month, endDate.day);
    final overnightNights = returnDate.difference(departureDate).inDays;

    if (overnightNights <= 0) {
      return 0;
    }

    if (crewOvernightUsd > 0) {
      return round(crewOvernightUsd * overnightNights);
    }

    return round(hourlyRateUsd * _overnightRateFactor * overnightNights);
  }
}
