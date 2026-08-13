import '../models/aeropuerto.dart';

const Map<String, String> verifiedAirportNames = {
  'MMSD': 'Aeropuerto Internacional de Los Cabos',
  'SJD': 'Aeropuerto Internacional de Los Cabos',
  'MMTO': 'Aeropuerto Internacional de Toluca',
  'TLC': 'Aeropuerto Internacional de Toluca',
};

Map<String, String> buildAirportNameIndex(Iterable<Airport> airports) {
  final names = <String, String>{...verifiedAirportNames};
  for (final airport in airports) {
    final label =
        airport.name.trim().isNotEmpty
            ? airport.name.trim()
            : (airport.city.trim().isNotEmpty
                ? airport.city.trim()
                : (airport.state?.trim() ?? ''));
    if (label.isEmpty) continue;
    for (final code in [airport.iata, airport.icao]) {
      final normalized = code?.trim().toUpperCase() ?? '';
      if (normalized.isNotEmpty) names[normalized] = label;
    }
  }
  return names;
}

String airportDisplayName(String code, Map<String, String> airportNames) {
  final normalized = code.trim().toUpperCase();
  if (normalized.isEmpty) return code;
  return airportNames[normalized] ?? code;
}
