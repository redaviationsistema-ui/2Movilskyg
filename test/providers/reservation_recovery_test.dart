import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/models/aeropuerto.dart';
import 'package:red_sky/providers/proveedor_reservaciones.dart';

void main() {
  test(
    '409 recovery removes only unavailable option and keeps request data',
    () {
      final provider =
          ReservationProvider()
            ..quoteMatches = [
              {'match_id': 'match-1', 'aircraft_id': 'aircraft-1'},
              {'match_id': 'match-2', 'aircraft_id': 'aircraft-2'},
            ]
            ..flightRequests = [
              {'id': 'request-1', 'aircraft_id': 'aircraft-1'},
            ];

      provider.handleAircraftUnavailable({
        'id': 'request-1',
        'aircraft_id': 'aircraft-1',
        'match_id': 'match-1',
      });

      expect(provider.quoteMatches, hasLength(1));
      expect(provider.quoteMatches.single['aircraft_id'], 'aircraft-2');
      expect(provider.flightRequests.single['id'], 'request-1');
    },
  );

  test('search draft restores route and preferences after process restart', () {
    final airportA = Airport(
      name: 'A',
      city: 'A',
      icao: 'MMAA',
      lat: 1,
      lng: 1,
    );
    final airportB = Airport(
      name: 'B',
      city: 'B',
      icao: 'MMBB',
      lat: 2,
      lng: 2,
    );
    final source =
        ReservationProvider()
          ..airports = [airportA, airportB]
          ..passengers = 4
          ..pets = 'Un perro'
          ..routes.first.fromAirport = airportA
          ..routes.first.toAirport = airportB
          ..routes.first.startDate = DateTime.utc(2027, 1, 2, 10);
    final draft = source.exportSearchDraft();

    final restored = ReservationProvider()..airports = [airportA, airportB];
    restored.restoreSearchDraft(draft);

    expect(restored.passengers, 4);
    expect(restored.pets, 'Un perro');
    expect(restored.routes.single.fromAirport?.icao, 'MMAA');
    expect(restored.routes.single.toAirport?.icao, 'MMBB');
    expect(restored.routes.single.startDate, DateTime.utc(2027, 1, 2, 10));
  });
}
