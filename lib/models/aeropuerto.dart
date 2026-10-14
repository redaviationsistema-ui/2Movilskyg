class Airport {
  final int? id;
  final String name;
  final String city;
  final String? state;
  final double lat;
  final double lng;
  final String? iata;
  final String? icao;
  final String? country;
  final bool hasCoordinateValues;

  Airport({
    this.id,
    required this.name,
    required this.city,
    this.state,
    this.iata,
    this.icao,
    this.country,
    this.hasCoordinateValues = true,
    required this.lat,
    required this.lng,
  });

  factory Airport.fromJson(Map<String, dynamic> json) {
    final idValue =
        json['id'] ??
        json['airport_id'] ??
        json['aeropuerto_id'] ??
        json['ID'] ??
        json['airportId'];
    final name =
        json['AEROPUERTO'] ??
        json['name'] ??
        json['airport'] ??
        json['nombre'] ??
        json['airport_name'] ??
        json['nombre_aeropuerto'] ??
        '';
    final city =
        json['CIUDAD'] ??
        json['city'] ??
        json['municipality'] ??
        json['ciudad'] ??
        '';
    final state = json['ESTADO'] ?? json['state'] ?? json['region'];
    final country =
        json['PAIS'] ??
        json['country'] ??
        json['COUNTRY'] ??
        json['iso_country'] ??
        'MEXICO';
    final iata =
        json['IATA'] ??
        json['iata'] ??
        json['iata_code'] ??
        json['codigo_iata'];
    final icao =
        json['ICAO'] ??
        json['icao'] ??
        json['icao_code'] ??
        json['codigo_icao'] ??
        json['gps_code'] ??
        json['ident'];
    final latValue = json['LATITUDE'] ?? json['lat'] ?? json['latitude'];
    final lngValue = json['LONGITUDE'] ?? json['lng'] ?? json['longitude'];
    final latitude = _toDoubleOrNull(latValue);
    final longitude = _toDoubleOrNull(lngValue);

    return Airport(
      id: _toInt(idValue),
      name: name,
      iata: iata,
      icao: icao,
      city: city,
      state: state,
      country: country,
      hasCoordinateValues: latitude != null && longitude != null,
      lat: latitude ?? 0,
      lng: longitude ?? 0,
    );
  }

  static double? _toDoubleOrNull(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.trim();
      if (normalized.isEmpty) return null;
      return double.tryParse(normalized);
    }
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'state': state,
      'lat': hasCoordinateValues ? lat : null,
      'lng': hasCoordinateValues ? lng : null,
      'iata': iata,
      'icao': icao,
      'country': country,
    };
  }
}
