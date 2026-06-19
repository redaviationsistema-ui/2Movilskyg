class Airport {
  final String name;
  final String city;
  final String? state;
  final double lat;
  final double lng;
  final String? iata;
  final String? icao;
  final String? country;

  Airport({
    required this.name,
    required this.city,
    this.state,
    this.iata,
    this.icao,
    this.country,
    required this.lat,
    required this.lng,
  });

  factory Airport.fromJson(Map<String, dynamic> json) {
    final name = json['AEROPUERTO'] ?? json['name'] ?? json['airport'] ?? '';
    final city = json['CIUDAD'] ?? json['city'] ?? '';
    final state = json['ESTADO'] ?? json['state'];
    final country = json['PAIS'] ?? json['country'];
    final iata =
        json['IATA'] ?? json['iata'] ?? json['iata_code'] ?? json['icao'];
    final icao =
        json['ICAO'] ?? json['icao'] ?? json['gps_code'] ?? json['ident'];
    final latValue = json['LATITUDE'] ?? json['lat'] ?? json['latitude'];
    final lngValue = json['LONGITUDE'] ?? json['lng'] ?? json['longitude'];

    return Airport(
      name: name,
      iata: iata,
      icao: icao,
      city: city,
      state: state,
      country: country,
      lat: _toDouble(latValue),
      lng: _toDouble(lngValue),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'name': name,
      'city': city,
      'state': state,
      'lat': lat,
      'lng': lng,
      'iata': iata,
      'icao': icao,
      'country': country,
    };
  }
}
