import '../models/aeropuerto.dart';

const Map<String, String> verifiedAirportNames = {
  'MMSD': 'Baja California Sur',
  'SJD': 'Baja California Sur',
  'MMTO': 'Estado de México',
  'TLC': 'Estado de México',
};

Map<String, String> buildAirportNameIndex(Iterable<Airport> airports) {
  final names = <String, String>{...verifiedAirportNames};
  for (final airport in airports) {
    final label =
        airport.state?.trim().isNotEmpty == true
            ? airport.state!.trim()
            : airport.name.trim();
    if (label.isEmpty) continue;
    for (final code in [airport.iata, airport.icao]) {
      final normalized = code?.trim().toUpperCase() ?? '';
      if (normalized.isNotEmpty) names.putIfAbsent(normalized, () => label);
    }
  }
  return names;
}

String airportDisplayName(String code, Map<String, String> airportNames) {
  final normalized = code.trim().toUpperCase();
  if (normalized.isEmpty) return code;
  return airportNames[normalized] ?? code;
}
