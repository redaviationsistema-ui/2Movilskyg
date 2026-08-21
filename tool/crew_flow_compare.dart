import 'dart:convert';
import 'dart:io';

import 'package:red_sky/screens/sobrecargo/crew_operation_flow.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/crew_flow_compare.dart <payload.json>',
    );
    exitCode = 64;
    return;
  }

  final file = File(args.first);
  final payload = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final assignment =
      payload['assignment'] is Map
          ? Map<String, dynamic>.from(payload['assignment'] as Map)
          : <String, dynamic>{};
  final workflow = Map<String, dynamic>.from(payload['workflow'] as Map);

  final snapshot = CrewOperationFlowSnapshot.fromPayload(
    workflow: workflow,
    canRespondToAssignment:
        '${assignment['workflow_status'] ?? workflow['assignment_status'] ?? workflow['crew_status'] ?? ''}'
            .trim() ==
        'pending_confirmation',
  );

  final output = {
    'assignmentConfirmed': snapshot.assignmentConfirmed,
    'workflowStatus': snapshot.workflowStatus,
    'currentStepId': snapshot.currentStepId,
    'steps':
        snapshot.steps
            .map(
              (step) => {
                'id': step.id,
                'label': step.label,
                'status': step.status,
                'available': step.available,
                'complete': step.complete,
              },
            )
            .toList(),
    'primaryAction': {
      'title': snapshot.primaryAction.title,
      'detail': snapshot.primaryAction.detail,
      'cta': snapshot.primaryAction.cta,
      'kind': snapshot.primaryAction.kind,
      'action': snapshot.primaryAction.action,
    },
    'trackingMilestones':
        snapshot.trackingMilestones
            .map(
              (item) => {
                'id': item.id,
                'label': item.label,
                'state': item.state,
                'timestamp': item.timestamp,
                'action': item.action,
              },
            )
            .toList(),
  };

  stdout.writeln(const JsonEncoder.withIndent('  ').convert(output));
}
