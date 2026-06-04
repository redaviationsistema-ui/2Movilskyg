import 'dart:math';

class DistanceCalculator {
  static const double _earthRadiusKm = 6371;
  static const double _kmPerNauticalMile = 1.852;
  static const double _ifrRoutingFactor = 1.23;

  static double toRad(double value) => value * pi / 180;

  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(toRad(lat1)) * cos(toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  static double distanceNm(double km) {
    final straightLineNm = km / _kmPerNauticalMile;
    return straightLineNm * _ifrRoutingFactor;
  }
}
