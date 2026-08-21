import 'package:flutter_test/flutter_test.dart';

import 'package:red_sky/screens/sobrecargo/crew_operation_flow.dart';

void main() {
  group('CrewOperationFlowSnapshot', () {
    test('builds validation and preparation state from workflow payload', () {
      final snapshot = CrewOperationFlowSnapshot.fromPayload(
        workflow: {
          'assignment_status': 'pending_confirmation',
          'status': 'pending_confirmation',
          'allowed_actions': const [],
          'checklists': const [],
          'tracking_events': const [],
        },
        canRespondToAssignment: true,
      );

      expect(snapshot.assignmentConfirmed, isFalse);
      expect(snapshot.currentStepId, 'validation');
      expect(snapshot.steps.first.status, 'current');
      expect(snapshot.primaryAction.kind, 'confirm_assignment');
    });

    test('opens tracking after preflight is complete', () {
      final snapshot = CrewOperationFlowSnapshot.fromPayload(
        workflow: {
          'assignment_status': 'confirmed',
          'status': 'boarding_completed',
          'allowed_actions': [
            {
              'type': 'transition',
              'status': 'in_flight',
              'label': 'Registrar despegue',
            },
          ],
          'checklists': [
            {
              'type': 'preparation',
              'items': [
                {'status': 'completed', 'is_required': true},
              ],
            },
            {
              'type': 'preflight',
              'items': [
                {'status': 'completed', 'is_required': true},
              ],
            },
            {
              'type': 'postflight',
              'items': [
                {'status': 'pending', 'is_required': true},
              ],
            },
          ],
          'tracking_events': const [
            {
              'status': 'crew_checkin',
              'title': 'Sobrecargo confirma check-in operativo',
            },
            {'status': 'cabina_lista', 'title': 'Cabina lista'},
            {'status': 'boarding_completed', 'title': 'Pasajeros recibidos'},
          ],
        },
        canRespondToAssignment: false,
      );

      expect(snapshot.currentStepId, 'tracking');
      expect(snapshot.primaryAction.kind, 'workflow_action');
      expect(snapshot.primaryAction.cta, 'Registrar despegue');
    });

    test(
      'keeps preflight as the primary action while checklist is current',
      () {
        final snapshot = CrewOperationFlowSnapshot.fromPayload(
          workflow: {
            'assignment_status': 'confirmed',
            'status': 'ready_for_operation',
            'allowed_actions': const [],
            'checklists': [
              {
                'type': 'preparation',
                'items': [
                  {'status': 'completed', 'is_required': true},
                ],
              },
              {
                'type': 'preflight',
                'items': [
                  {'status': 'pending', 'is_required': true},
                ],
              },
            ],
            'tracking_events': const [],
          },
          canRespondToAssignment: false,
        );

        expect(snapshot.currentStepId, 'checklist');
        expect(snapshot.stepById('checklist')?.status, 'current');
        expect(snapshot.stepById('tracking')?.status, 'blocked');
        expect(snapshot.stepById('closure')?.status, 'blocked');
        expect(snapshot.primaryAction.kind, 'open_checklist');
        expect(
          snapshot.primaryAction.title,
          'Siguiente paso: Checklist pre-vuelo',
        );
        expect(snapshot.primaryAction.cta, 'Continuar checklist pre-vuelo');
      },
    );
  });
}
