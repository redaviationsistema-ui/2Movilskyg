import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/core/payment_authorization_state.dart';

void main() {
  test('authorizes checkout only with all backend confirmations', () {
    final state = PaymentAuthorizationState.fromBackend({
      'authorized': true,
      'can_pay': true,
      'aircraft_available': true,
      'blocking_reasons': const [],
      'contract': {'envelope_status': 'completed'},
    });

    expect(state.isAuthorized, isTrue);
    expect(state.canPay, isTrue);
    expect(state.aircraftAvailable, isTrue);
  });

  test('contract signed is not equivalent to DocuSign completed', () {
    final state = PaymentAuthorizationState.fromBackend({
      'request_ready': true,
      'reservation_ready': true,
      'aircraft_available': true,
      'payment_authorized': true,
      'contract': {'status': 'signed'},
    });

    expect(state.isAuthorized, isFalse);
    expect(state.message, contains('completed'));
  });

  test('aircraft unavailable fails closed with explicit signal', () {
    final state = PaymentAuthorizationState.fromBackend({
      'authorized': false,
      'can_pay': false,
      'aircraft_available': false,
      'blocking_reasons': const ['AIRCRAFT_NOT_AVAILABLE'],
      'invalid_reason': 'aircraft_booked_by_other_reservation',
      'contract': {'docusign_status': 'completed'},
    });

    expect(state.isAuthorized, isFalse);
    expect(state.aircraftAvailable, isFalse);
  });

  test(
    'accepts authorized backend payload even when aircraft flag is inconsistent',
    () {
      final state = PaymentAuthorizationState.fromBackend({
        'authorized': true,
        'can_pay': true,
        'aircraft_available': false,
        'blocking_reasons': const [],
        'availability': {'available': true, 'conflicting_block_id': null},
        'contract': {'docusign_status': 'completed'},
      });

      expect(state.isAuthorized, isTrue);
      expect(state.canPay, isTrue);
      expect(state.aircraftAvailable, isTrue);
      expect(state.hasInconsistentAvailabilityPayload, isTrue);
    },
  );
}
