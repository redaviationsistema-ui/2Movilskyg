import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/core/client_workflow_status.dart';

void main() {
  group('client workflow status', () {
    test(
      'keeps plain newly created request in reserved stage before provider routing',
      () {
        final request = <String, dynamic>{
          'id': 'req_123',
          'flight_request_id': 'req_123',
          'status': 'reserved',
          'workflow_status': 'reserva solicitada',
        };

        expect(resolveClientWorkflowStage(request), 'reserved');
      },
    );

    test(
      'moves request to provider pending when backend signals sent to provider',
      () {
        final request = <String, dynamic>{
          'id': 'req_124',
          'flight_request_id': 'req_124',
          'provider_id': 'prov_1',
          'match_id': 'match_1',
          'status': 'reserved',
          'workflow_status': 'reserva solicitada',
          'booking_status': 'reserved',
          'next_action': 'sent_to_provider',
        };

        expect(resolveClientWorkflowStage(request), 'provider_pending');
      },
    );

    test(
      'prioritizes pending provider response over premature provider accepted status',
      () {
        final request = <String, dynamic>{
          'id': 'req_456',
          'workflow_status': 'provider_accepted',
          'status': 'provider_accepted',
          'next_action': 'sent_to_provider',
          'visibility_payload': {
            'admin_flow': {
              'stage_label': 'Responder solicitud',
              'action_required': 'Pendiente de aceptar o rechazar',
            },
          },
        };

        expect(resolveClientWorkflowStage(request), 'provider_pending');
      },
    );
  });
}
