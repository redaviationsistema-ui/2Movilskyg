import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/models/client_operation_tracking.dart';

void main() {
  test('parses the real operation tracking envelope and timeline', () {
    final tracking = ClientOperationTracking.fromJson({
      'success': true,
      'operation': {
        'id': 42,
        'status': 'in_flight',
        'timeline': [
          {
            'id': 7,
            'status': 'in_flight',
            'title': 'Salida confirmada',
            'description': 'El vuelo se encuentra en curso.',
            'created_at': '2026-09-23T15:00:00Z',
          },
        ],
      },
    });

    expect(tracking.operationId, '42');
    expect(tracking.status, 'in_flight');
    expect(tracking.timeline, hasLength(1));
    expect(tracking.timeline.single.title, 'Salida confirmada');
    expect(tracking.timeline.single.createdAt, isNotNull);
  });

  test('handles an empty backend timeline without fake events', () {
    final tracking = ClientOperationTracking.fromJson({
      'operation': {'id': 42, 'status': 'preparation', 'timeline': []},
    });

    expect(tracking.timeline, isEmpty);
  });
}
