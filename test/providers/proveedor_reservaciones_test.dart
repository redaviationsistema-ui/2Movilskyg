import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/core/client_workflow_status.dart';
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
}
