import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/core/airport_name_index.dart';
import 'package:red_sky/models/aeropuerto.dart';

void main() {
  test('parses Spanish airport and ICAO field variants', () {
    final airport = Airport.fromJson({
      'nombre': 'Aeropuerto Internacional de Toluca',
      'municipality': 'Toluca',
      'codigo_iata': 'TLC',
      'codigo_icao': 'MMTO',
    });

    expect(airport.name, 'Aeropuerto Internacional de Toluca');
    expect(airport.city, 'Toluca');
    expect(airport.iata, 'TLC');
    expect(airport.icao, 'MMTO');
  });

  test('resolves the same airport state by IATA or ICAO', () {
    final names = buildAirportNameIndex([
      Airport.fromJson({
        'nombre': 'Aeropuerto Intercontinental de Querétaro',
        'municipality': 'Querétaro',
        'state': 'Querétaro',
        'codigo_iata': 'QRO',
        'codigo_icao': 'MMQT',
      }),
    ]);

    expect(airportDisplayName('MMQT', names), 'Querétaro');
    expect(airportDisplayName('qro', names), 'Querétaro');
  });

  test('keeps the code as a safe fallback without an airport catalog', () {
    expect(airportDisplayName('XXXX', const {}), 'XXXX');
  });

  test('shows verified states before the remote catalog finishes', () {
    final names = buildAirportNameIndex(const []);

    expect(airportDisplayName('MMSD', names), 'Baja California Sur');
    expect(airportDisplayName('MMTO', names), 'Estado de México');
  });
}
