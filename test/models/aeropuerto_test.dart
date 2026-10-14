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

  test('parses lowercase, uppercase, and canonical coordinate fields', () {
    for (final fields in [
      {'latitude': '19.3371', 'longitude': '-99.566'},
      {'lat': 19.3371, 'lng': -99.566},
      {'LATITUDE': 19.3371, 'LONGITUDE': -99.566},
    ]) {
      final airport = Airport.fromJson(fields);

      expect(airport.hasCoordinateValues, isTrue);
      expect(airport.lat, 19.3371);
      expect(airport.lng, -99.566);
    }
  });

  test(
    'keeps incomplete coordinate data absent through cache serialization',
    () {
      final airport = Airport.fromJson({
        'id': 10,
        'name': 'Airport',
        'city': 'City',
        'lat': 'not-a-coordinate',
        'lng': -99.566,
      });

      expect(airport.hasCoordinateValues, isFalse);
      final cached = Airport.fromJson(airport.toCacheMap());
      expect(cached.hasCoordinateValues, isFalse);
    },
  );

  test('resolves the same airport name by IATA or ICAO', () {
    final names = buildAirportNameIndex([
      Airport.fromJson({
        'nombre': 'Aeropuerto Intercontinental de Querétaro',
        'municipality': 'Querétaro',
        'state': 'Querétaro',
        'codigo_iata': 'QRO',
        'codigo_icao': 'MMQT',
      }),
    ]);

    expect(
      airportDisplayName('MMQT', names),
      'Aeropuerto Intercontinental de Querétaro',
    );
    expect(
      airportDisplayName('qro', names),
      'Aeropuerto Intercontinental de Querétaro',
    );
  });

  test('keeps the code as a safe fallback without an airport catalog', () {
    expect(airportDisplayName('XXXX', const {}), 'XXXX');
  });

  test('shows verified airport names before the remote catalog finishes', () {
    final names = buildAirportNameIndex(const []);

    expect(
      airportDisplayName('MMSD', names),
      'Aeropuerto Internacional de Los Cabos',
    );
    expect(
      airportDisplayName('MMTO', names),
      'Aeropuerto Internacional de Toluca',
    );
  });
}
