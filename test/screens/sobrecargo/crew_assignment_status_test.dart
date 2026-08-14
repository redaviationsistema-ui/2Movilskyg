import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/screens/sobrecargo/pantalla_espacio_sobrecargo.dart';

void main() {
  group('Crew assignment status resolution', () {
    Map<String, dynamic> payload({
      String status = '',
      String crewStatus = '',
      String responseStatus = '',
      String assignmentResponse = '',
      List<Map<String, dynamic>> timeline = const [],
    }) {
      return {
        if (status.isNotEmpty) 'status': status,
        if (crewStatus.isNotEmpty) 'crew_status': crewStatus,
        if (responseStatus.isNotEmpty) 'response_status': responseStatus,
        if (assignmentResponse.isNotEmpty)
          'assignment_response': assignmentResponse,
        if (timeline.isNotEmpty) 'timeline': timeline,
      };
    }

    test(
      'keeps pending_confirmation as Pendiente when no confirmation exists',
      () {
        final status = resolveCrewAssignmentStatusForPayload(
          payload(status: 'pending_confirmation'),
        );

        expect(status, 'Pendiente');
      },
    );

    test(
      'prioritizes response_status Confirmado over pending operation status',
      () {
        final status = resolveCrewAssignmentStatusForPayload(
          payload(status: 'pending_confirmation', responseStatus: 'Confirmado'),
        );

        expect(status, 'Confirmado');
      },
    );

    test(
      'prioritizes assignment_response accepted over pending operation status',
      () {
        final status = resolveCrewAssignmentStatusForPayload(
          payload(
            status: 'pending_confirmation',
            assignmentResponse: 'accepted',
          ),
        );

        expect(status, 'Confirmado');
      },
    );

    test(
      'prioritizes crew_status pending_confirmation over active operation hints',
      () {
        final status = resolveCrewAssignmentStatusForPayload(
          payload(
            status: 'in_progress',
            crewStatus: 'pending_confirmation',
            timeline: const [
              {'status': 'service_started'},
            ],
          ),
        );

        expect(status, 'Pendiente');
      },
    );

    test('maps crew_confirmed to Confirmado dynamically', () {
      final status = resolveCrewAssignmentStatusForPayload(
        payload(crewStatus: 'crew_confirmed', status: 'pending_confirmation'),
      );

      expect(status, 'Confirmado');
    });
  });
}
