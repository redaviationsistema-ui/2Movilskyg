import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/core/stripe_checkout_flow.dart';

void main() {
  group('parseReservationCheckoutReturn', () {
    test('uses query values when Stripe returns full context', () {
      final uri = Uri.parse(
        'redsky://cliente/pago?checkout=success&session_id=cs_test_123'
        '&reservation_id=99&flight_request_id=77',
      );

      final context = parseReservationCheckoutReturn(uri);

      expect(context.checkoutResult, 'success');
      expect(context.sessionId, 'cs_test_123');
      expect(context.reservationId, '99');
      expect(context.flightRequestId, '77');
      expect(context.hasSessionId, isTrue);
      expect(context.hasReferenceIdentity, isTrue);
      expect(context.isCancelled, isFalse);
    });

    test(
      'falls back to reservation identifiers when session id is missing',
      () {
        final uri = Uri.parse(
          'redsky://cliente/pago?checkout=success&reservation_id=55'
          '&flight_request_id=44',
        );

        final context = parseReservationCheckoutReturn(
          uri,
          fallbackSessionId: '',
          fallbackReservationId: 'existing-res',
          fallbackFlightRequestId: 'existing-flight',
        );

        expect(context.sessionId, '');
        expect(context.reservationId, '55');
        expect(context.flightRequestId, '44');
        expect(context.hasSessionId, isFalse);
        expect(context.hasReferenceIdentity, isTrue);
      },
    );

    test('uses fallback values when query omits them', () {
      final uri = Uri.parse('redsky://cliente/pago?checkout=cancelled');

      final context = parseReservationCheckoutReturn(
        uri,
        fallbackSessionId: 'cs_live_123',
        fallbackReservationId: '11',
        fallbackFlightRequestId: '22',
      );

      expect(context.sessionId, 'cs_live_123');
      expect(context.reservationId, '11');
      expect(context.flightRequestId, '22');
      expect(context.isCancelled, isTrue);
    });

    test('accepts alternate booking and request parameter names', () {
      final uri = Uri.parse(
        'redsky://cliente/pago?checkout=success&booking_id=901'
        '&request_id=902&checkoutSessionId=cs_test_alt',
      );

      final context = parseReservationCheckoutReturn(uri);

      expect(context.sessionId, 'cs_test_alt');
      expect(context.reservationId, '901');
      expect(context.flightRequestId, '902');
      expect(context.hasReferenceIdentity, isTrue);
    });
  });

  group('buildReservationPaymentBackendReturnUrl', () {
    test('includes reservation and flight request ids in backend url', () {
      final url = buildReservationPaymentBackendReturnUrl(
        baseUrl: 'https://uber-aviones.onrender.com/api/v1/',
        checkout: 'success',
        reservationId: '501',
        flightRequestId: '601',
      );

      final uri = Uri.parse(url);
      expect(
        uri.toString(),
        contains('/api/v1/client/flight-payment/mobile-return'),
      );
      expect(uri.queryParameters['checkout'], 'success');
      expect(uri.queryParameters['session_id'], '{CHECKOUT_SESSION_ID}');
      expect(uri.queryParameters['reservation_id'], '501');
      expect(uri.queryParameters['flight_request_id'], '601');
    });

    test('normalizes cancel checkout value for mobile return', () {
      final url = buildReservationPaymentBackendReturnUrl(
        baseUrl: '',
        checkout: 'cancel',
        reservationId: '12',
      );

      final uri = Uri.parse(url);
      expect(uri.scheme, 'redsky');
      expect(uri.host, 'cliente');
      expect(uri.path, '/pago');
      expect(uri.queryParameters['checkout'], 'cancelled');
      expect(uri.queryParameters['reservation_id'], '12');
    });

    test('omits empty ids from fallback mobile url', () {
      final url = buildReservationPaymentBackendReturnUrl(
        baseUrl: '',
        checkout: 'success',
      );

      final uri = Uri.parse(url);
      expect(uri.queryParameters.containsKey('reservation_id'), isFalse);
      expect(uri.queryParameters.containsKey('flight_request_id'), isFalse);
    });
  });

  group('extractStripeCheckoutUrl', () {
    test('reads url from nested checkout_session payload', () {
      final payload = <String, dynamic>{
        'data': {
          'checkout_session': {
            'id': 'cs_test_123',
            'url': 'https://checkout.stripe.com/c/pay/cs_test_123',
          },
        },
      };

      expect(
        extractStripeCheckoutUrl(payload),
        'https://checkout.stripe.com/c/pay/cs_test_123',
      );
    });

    test('prefers explicit checkout_url when available', () {
      final payload = <String, dynamic>{
        'checkout_url': 'https://checkout.stripe.com/explicit',
        'checkout_session': {'url': 'https://checkout.stripe.com/nested'},
      };

      expect(
        extractStripeCheckoutUrl(payload),
        'https://checkout.stripe.com/explicit',
      );
    });

    test('reads url from session alias nested in data', () {
      final payload = <String, dynamic>{
        'data': {
          'session': {
            'id': 'cs_test_alias',
            'url': 'https://checkout.stripe.com/c/pay/cs_test_alias',
          },
        },
      };

      expect(
        extractStripeCheckoutUrl(payload),
        'https://checkout.stripe.com/c/pay/cs_test_alias',
      );
    });

    test('reads payment link style fields when checkout_url is absent', () {
      final payload = <String, dynamic>{
        'payment_order': {
          'payment_link': 'https://checkout.stripe.com/pay/link_123',
        },
      };

      expect(
        extractStripeCheckoutUrl(payload),
        'https://checkout.stripe.com/pay/link_123',
      );
    });

    test('returns empty string when no supported url field exists', () {
      final payload = <String, dynamic>{
        'checkout_session': {'id': 'cs_test_only'},
      };

      expect(extractStripeCheckoutUrl(payload), isEmpty);
    });

    test(
      'returns empty string when backend marks checkout as non reusable',
      () {
        final payload = <String, dynamic>{
          'checkout_url': 'https://checkout.stripe.com/explicit',
          'checkout_reusable': false,
          'requires_new_checkout': true,
        };

        expect(extractStripeCheckoutUrl(payload), isEmpty);
        expect(stripeCheckoutSessionCanBeReused(payload), isFalse);
        expect(stripeCheckoutSessionRequiresNewCheckout(payload), isTrue);
      },
    );

    test('detects expired checkout from Stripe session status', () {
      final payload = <String, dynamic>{
        'payment_order': {
          'gateway_response': {
            'status': 'expired',
            'payment_status': 'unpaid',
            'url': 'https://checkout.stripe.com/c/pay/cs_test_expired',
          },
        },
      };

      expect(stripeCheckoutSessionCanBeReused(payload), isFalse);
      expect(stripeCheckoutSessionRequiresNewCheckout(payload), isTrue);
      expect(extractStripeCheckoutUrl(payload), isEmpty);
    });
  });
}
