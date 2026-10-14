import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/models/client_operation_tracking.dart';
import 'package:red_sky/screens/cliente/presentation/tracking_presentation.dart';

ClientOperationTimelineEvent event(
  Map<String, dynamic> values,
) => ClientOperationTimelineEvent.fromJson({
  'id': 1,
  'operation_id': 42,
  'title': 'Liberacion operativa del proveedor',
  'status': 'en_vuelo',
  'created_at': '2026-10-14T15:00:00Z',
  'description':
      'Estado: operational_ready | Aeronave: LEARJET 31A | Workflow: tracking_live',
  ...values,
});
ClientOperationTracking tracking(
  List<ClientOperationTimelineEvent> events, {
  String status = 'en_vuelo',
}) => ClientOperationTracking(
  operationId: '42',
  status: status,
  timeline: events,
);

void main() {
  test(
    'release workflow normalization is not independent evidence of takeoff',
    () {
      final update = event({});
      final presentation = TrackingStatusPresentation.fromTracking(
        tracking([update]),
      );
      expect(presentation.title, 'Listo para operar');
      expect(presentation.description, contains('no confirma el despegue'));
      expect(trackingEventLabel(update), 'Listo para operar');
      expect(trackingReleaseAircraftLabel([update]), 'LEARJET 31A');
      final description = trackingEventDescription(update);
      expect(description, contains('Seguimiento operativo activo'));
      expect(description, contains('LEARJET 31A'));
      expect(description, isNot(contains('operational_ready')));
      expect(description, isNot(contains('tracking_live')));
    },
  );

  test(
    'tracking live and ambiguous en_vuelo never imply airborne by themselves',
    () {
      for (final status in ['tracking_live', 'en_vuelo']) {
        expect(
          TrackingStatusPresentation.fromTracking(
            tracking([], status: status),
          ).title,
          'Seguimiento operativo activo',
        );
      }
      expect(
        TrackingStatusPresentation.fromValue('operational_ready').title,
        'Listo para operar',
      );
      expect(
        TrackingStatusPresentation.fromValue('not_ready').title,
        'Estado operativo por confirmar',
      );
    },
  );

  test('keeps distinct ids, differing contents and records without ids', () {
    final records = [
      event({'id': 1}),
      event({'id': 2}),
      event({'id': 3}),
      event({'id': 4}),
      event({'id': null}),
      event({'id': null}),
    ];
    expect(trackingVisibleEvents(tracking(records)), hasLength(6));
    expect(
      trackingVisibleEvents(
        tracking([
          event({}),
          event({'created_by': 9}),
        ]),
      ),
      hasLength(2),
    );
  });

  test(
    'deduplicates only identical identified copies and orders newest first',
    () {
      final records = [
        event({'id': 2, 'created_at': '2026-10-13T15:00:00Z'}),
        event({}),
        event({}),
      ];
      final visible = trackingVisibleEvents(tracking(records));
      expect(visible.map((entry) => entry.id), ['1', '2']);
      expect(records, hasLength(3));
      expect(visible.first.sourceSignature, isNotEmpty);
    },
  );

  test(
    'excludes another operation and preserves unknown states without completion',
    () {
      expect(
        trackingVisibleEvents(
          tracking([
            event({'operation_id': 99}),
          ]),
        ),
        isEmpty,
      );
      expect(
        trackingEventLabel(
          event({'description': '', 'status': 'future_state'}),
        ),
        'Estado por confirmar',
      );
      expect(trackingStateLabel('incomplete'), 'Estado por confirmar');
      expect(
        TrackingStatusPresentation.fromValue('future_state').terminal,
        isFalse,
      );
    },
  );

  test('unknown current state is not upgraded by a historical release', () {
    expect(
      TrackingStatusPresentation.fromTracking(
        tracking([event({})], status: 'future_state'),
      ).title,
      'Estado operativo por confirmar',
    );
    expect(
      trackingEventLabel(event({'description': '', 'status': 'completed'})),
      'Completado',
    );
  });

  test(
    'independent flight update corroborates ambiguous operation but old release does not override it',
    () {
      final airborne = event({
        'id': 2,
        'title': 'Salida confirmada',
        'description': '',
        'created_at': '2026-10-14T16:00:00Z',
      });
      expect(
        TrackingStatusPresentation.fromTracking(
          tracking([event({}), airborne]),
        ).title,
        'Tu vuelo está en curso',
      );
      for (final terminal in ['completed', 'cancelled']) {
        final result = TrackingStatusPresentation.fromTracking(
          tracking([event({})], status: terminal),
        );
        expect(result.terminal, isTrue);
        expect(result.title, isNot('Listo para operar'));
        expect(result.nextDescription, isNot(contains('preparación')));
      }
    },
  );
}
