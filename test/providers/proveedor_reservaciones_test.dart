import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/core/client_workflow_status.dart';
import 'package:red_sky/models/aeronave.dart';
import 'package:red_sky/models/aeropuerto.dart';
import 'package:red_sky/providers/proveedor_reservaciones.dart';

void main() {
  group('ReservationProvider rememberCreatedFlightRequest', () {
    test(
      'defaults new request to provider pending when it was sent to provider',
      () {
        final provider = ReservationProvider();

        provider.rememberCreatedFlightRequest({
          'id': 'req_001',
          'provider_id': 'prov_001',
          'match_id': 'match_001',
        });

        expect(provider.flightRequests, isNotEmpty);
        final request = provider.flightRequests.first;

        expect(request['status'], 'reserved');
        expect(request['workflow_status'], 'reserva solicitada');
        expect(request['booking_status'], 'reserved');
        expect(request['next_action'], 'sent_to_provider');
        expect(resolveClientWorkflowStage(request), 'provider_pending');
      },
    );

    test('preserves backend workflow when it is explicitly provided', () {
      final provider = ReservationProvider();

      provider.rememberCreatedFlightRequest({
        'id': 'req_002',
        'provider_id': 'prov_002',
        'match_id': 'match_002',
        'status': 'provider_pending',
        'workflow_status': 'provider_pending',
      });

      expect(provider.flightRequests, isNotEmpty);
      final request = provider.flightRequests.first;

      expect(request['status'], 'provider_pending');
      expect(request['workflow_status'], 'provider_pending');
      expect(resolveClientWorkflowStage(request), 'provider_pending');
    });
  });

  test(
    'restoring a search keeps aircraft results and restores named airports',
    () {
      final provider = ReservationProvider();
      final aircraft = Aircraft.fromJson({
        'id': 'aircraft_550',
        'name': 'Cessna Citation II (550)',
        'aircraft_type': 'Light Jet',
        'capacity_passengers': 7,
      });
      final origin = Airport.fromJson({
        'name': 'Aeropuerto Internacional de Los Cabos',
        'iata': 'SJD',
        'icao': 'MMSD',
        'city': 'San José del Cabo',
      });
      final destination = Airport.fromJson({
        'name': 'Aeropuerto Internacional de Toluca',
        'iata': 'TLC',
        'icao': 'MMTO',
        'city': 'Toluca',
      });
      provider.aircraftFleet = [aircraft];
      provider.airports = [origin, destination];

      provider.restoreSearchDraft({
        'passengers': 1,
        'selected_aircraft_id': 'aircraft_550',
        'routes': [
          {
            'origin': 'MMSD',
            'destination': 'MMTO',
            'departure_datetime': '2026-07-27T15:30:00',
            'passengers': 1,
          },
        ],
      });

      expect(provider.aircraftFleet, contains(same(aircraft)));
      expect(provider.selectedAircraft, same(aircraft));
      expect(
        provider.routes.single.fromAirport?.name,
        'Aeropuerto Internacional de Los Cabos',
      );
      expect(
        provider.routes.single.toAirport?.name,
        'Aeropuerto Internacional de Toluca',
      );
    },
  );
}
