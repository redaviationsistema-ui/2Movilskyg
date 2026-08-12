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

  test(
    '409 recovery clears the conflicting selection and preserves search data',
    () {
      final airportA = Airport(
        name: 'Toluca',
        city: 'Toluca',
        icao: 'MMTO',
        lat: 1,
        lng: 1,
      );
      final airportB = Airport(
        name: 'Monterrey',
        city: 'Monterrey',
        icao: 'MMMY',
        lat: 2,
        lng: 2,
      );
      final provider =
          ReservationProvider()
            ..passengers = 6
            ..selectedAircraft = null
            ..selectedQuoteMatch = {
              'match_id': 'match-1',
              'aircraft_id': 'aircraft-1',
            }
            ..quoteMatches = [
              {'match_id': 'match-1', 'aircraft_id': 'aircraft-1'},
              {'match_id': 'match-2', 'aircraft_id': 'aircraft-2'},
            ]
            ..routes.first.fromAirport = airportA
            ..routes.first.toAirport = airportB
            ..routes.first.startDate = DateTime.utc(2027, 1, 2, 10);

      provider.handleAircraftUnavailable({
        'aircraft_id': 'aircraft-1',
        'match_id': 'match-1',
      });

      expect(provider.selectedAircraft, isNull);
      expect(provider.selectedQuoteMatch, isNull);
      expect(provider.quoteMatches, hasLength(1));
      expect(provider.quoteMatches.single['aircraft_id'], 'aircraft-2');
      expect(provider.passengers, 6);
      expect(provider.routes.single.fromAirport?.icao, 'MMTO');
      expect(provider.routes.single.toAirport?.icao, 'MMMY');
      expect(provider.routes.single.startDate, DateTime.utc(2027, 1, 2, 10));
    },
  );

  test('409 recovery removes only the conflicting aircraft id', () {
    final provider =
        ReservationProvider()
          ..quoteMatches = [
            {'match_id': 'match-1', 'aircraft_id': 'aircraft-25'},
            {'match_id': 'match-2', 'aircraft_id': 'aircraft-25'},
            {'match_id': 'match-3', 'aircraft_id': 'aircraft-40'},
          ];

    provider.handleAircraftUnavailable({'aircraft_id': 'aircraft-25'});

    expect(provider.quoteMatches.map((quote) => quote['match_id']).toList(), [
      'match-3',
    ]);
  });

  test(
    '409 recovery removes only the conflicting match id when aircraft id is absent',
    () {
      final provider =
          ReservationProvider()
            ..quoteMatches = [
              {'match_id': 'match-1', 'aircraft_id': 'aircraft-25'},
              {'match_id': 'match-2', 'aircraft_id': 'aircraft-25'},
              {'match_id': 'match-3', 'aircraft_id': 'aircraft-40'},
            ];

      provider.handleAircraftUnavailable({'match_id': 'match-2'});

      expect(provider.quoteMatches.map((quote) => quote['match_id']).toList(), [
        'match-1',
        'match-3',
      ]);
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
