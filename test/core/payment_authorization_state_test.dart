import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/core/payment_authorization_state.dart';

void main() {
  test('authorizes checkout only with all backend confirmations', () {
    final state = PaymentAuthorizationState.fromBackend({
      'request_ready': true,
      'reservation_ready': true,
      'aircraft_available': true,
      'payment_authorized': true,
      'contract': {'envelope_status': 'completed'},
    });

    expect(state.isAuthorized, isTrue);
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
      'request_ready': true,
      'reservation_ready': true,
      'aircraft_available': false,
      'payment_authorized': true,
      'contract': {'docusign_status': 'completed'},
    });

    expect(state.isAuthorized, isFalse);
    expect(state.aircraftAvailable, isFalse);
  });
}
