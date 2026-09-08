import 'package:flutter_test/flutter_test.dart';

import 'package:red_sky/screens/sobrecargo/crew_operation_flow.dart';

void main() {
  group('CrewOperationFlowSnapshot', () {
    Map<String, dynamic> trackingPayload({
      required String phase,
      required Map<String, dynamic> nextAction,
    }) => {
      'assignment_status': 'confirmed',
      'status': 'boarding_completed',
      'current_step': 'tracking',
      'current_phase': phase,
      'next_action': nextAction,
      'allowed_actions': [nextAction],
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
      ],
      'tracking_events': const [
        {'status': 'crew_checkin'},
        {'status': 'cabina_lista'},
        {'status': 'pasajeros_recibidos'},
      ],
    };

    test('builds validation and preparation state from workflow payload', () {
      final snapshot = CrewOperationFlowSnapshot.fromPayload(
        workflow: {
          'assignment_status': 'pending_confirmation',
          'status': 'pending_confirmation',
          'allowed_actions': const [],
          'checklists': const [],
          'tracking_events': const [
            {'status': 'crew_checkin', 'title': 'Llegada registrada'},
          ],
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
          'current_step': 'tracking',
          'current_phase': 'departure',
          'next_action': {
            'type': 'departure',
            'label': 'Registrar despegue',
            'status': 'in_flight',
          },
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
            'current_step': 'preflight',
            'current_phase': 'preflight',
            'next_action': null,
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
            'tracking_events': const [
              {'status': 'crew_checkin', 'title': 'Llegada registrada'},
            ],
          },
          canRespondToAssignment: false,
        );

        expect(snapshot.currentStepId, 'checklist');
        expect(snapshot.stepById('checklist')?.status, 'current');
        expect(snapshot.stepById('tracking')?.status, 'locked');
        expect(snapshot.stepById('closure')?.status, 'locked');
        expect(snapshot.primaryAction.kind, 'open_checklist');
        expect(
          snapshot.primaryAction.title,
          'Siguiente paso: Checklist pre-vuelo',
        );
        expect(snapshot.primaryAction.cta, 'Continuar checklist pre-vuelo');
      },
    );
    test('uses landing and disembark next_action from backend', () {
      final landing = CrewOperationFlowSnapshot.fromPayload(
        workflow: trackingPayload(
          phase: 'landing',
          nextAction: {
            'type': 'landing',
            'label': 'Registrar aterrizaje',
            'status': 'landed',
          },
        ),
        canRespondToAssignment: false,
      );
      expect(landing.primaryAction.cta, 'Registrar aterrizaje');

      final disembark = CrewOperationFlowSnapshot.fromPayload(
        workflow: trackingPayload(
          phase: 'disembark',
          nextAction: {
            'type': 'disembark',
            'label': 'Registrar desembarque',
            'status': 'postflight_pending',
          },
        ),
        canRespondToAssignment: false,
      );
      expect(disembark.primaryAction.cta, 'Registrar desembarque');
    });

    test('opens postflight and report actions from canonical step', () {
      final postflight = CrewOperationFlowSnapshot.fromPayload(
        workflow: {
          'assignment_status': 'confirmed',
          'current_step': 'postflight',
          'current_phase': 'postflight',
          'next_action': null,
          'allowed_actions': const [],
          'checklists': const [],
          'tracking_events': const [],
        },
        canRespondToAssignment: false,
      );
      expect(postflight.currentStepId, 'postflight');
      expect(postflight.primaryAction.kind, 'open_postflight');

      final closure = CrewOperationFlowSnapshot.fromPayload(
        workflow: {
          'assignment_status': 'confirmed',
          'current_step': 'closure',
          'current_phase': 'closure',
          'next_action': {
            'type': 'submit_report',
            'label': 'Enviar reporte final',
          },
          'allowed_actions': [
            {'type': 'submit_report', 'label': 'Enviar reporte final'},
          ],
          'checklists': const [],
          'tracking_events': const [],
        },
        canRespondToAssignment: false,
      );
      expect(closure.primaryAction.kind, 'submit_report');
      expect(closure.primaryAction.cta, 'Enviar reporte final');

      final completed = CrewOperationFlowSnapshot.fromPayload(
        workflow: {
          'assignment_status': 'confirmed',
          'current_step': 'completed',
          'current_phase': 'completed',
          'next_action': null,
          'allowed_actions': const [],
          'checklists': const [],
          'tracking_events': const [],
        },
        canRespondToAssignment: false,
      );
      expect(completed.currentStepId, 'completed');
      expect(completed.primaryAction.kind, 'completed');
      expect(completed.primaryAction.cta, isEmpty);
    });

    test('preserves recoverable and blocked inconsistency states', () {
      final recoverable = CrewOperationFlowSnapshot.fromPayload(
        workflow: {
          'assignment_status': 'confirmed',
          'current_step': 'tracking',
          'current_phase': 'departure',
          'next_action': {
            'type': 'departure',
            'label': 'Registrar despegue',
            'status': 'in_flight',
          },
          'allowed_actions': [
            {
              'type': 'departure',
              'label': 'Registrar despegue',
              'status': 'in_flight',
            },
          ],
          'workflow_inconsistent': true,
          'blocking_reason': 'Historial recuperable',
          'checklists': const [],
          'tracking_events': const [],
        },
        canRespondToAssignment: false,
      );
      expect(recoverable.primaryAction.kind, 'workflow_action');

      final blocked = CrewOperationFlowSnapshot.fromPayload(
        workflow: {
          'assignment_status': 'confirmed',
          'current_step': 'tracking',
          'workflow_inconsistent': true,
          'blocking_reason': 'Incidencia crítica abierta',
          'next_action': null,
          'allowed_actions': const [],
          'checklists': const [],
          'tracking_events': const [],
        },
        canRespondToAssignment: false,
      );
      expect(blocked.primaryAction.kind, 'blocked');
      expect(blocked.primaryAction.cta, isEmpty);
    });
  });
}
