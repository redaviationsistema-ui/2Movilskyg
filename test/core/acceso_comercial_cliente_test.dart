import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:red_sky/core/acceso_comercial_cliente.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
  });

  group('commercial access payment records', () {
    test('activates access from a paid latest_payment record', () {
      final state = resolveCommercialAccessState({
        'commercial_access': {
          'status': 'active',
          'has_paid_access': true,
          'access_is_active': true,
          'latest_payment': {
            'status': 'paid',
            'billing_period_end': '2099-12-31',
          },
        },
      });

      expect(state.hasPaidAccess, isTrue);
      expect(state.canReserve, isTrue);
      expect(state.status, 'active');
    });

    test('syncs nested backend payment data into active access', () {
      final synced = syncCommercialAccessPayload(null, {
        'data': {
          'access': {
            'status': 'active',
            'has_paid_access': true,
            'access_is_active': true,
            'latest_payment': {
              'payment_status': 'succeeded',
              'billing_period_end': '2099-12-31',
            },
          },
        },
      });

      final state = resolveCommercialAccessState(synced);
      expect(state.hasPaidAccess, isTrue);
      expect(state.canReserve, isTrue);
      expect(synced['has_paid_access'], isTrue);
    });

    test('does not activate access from a failed payment record', () {
      final state = resolveCommercialAccessState({
        'commercial_access': {
          'status': 'payment_pending',
          'latest_payment': {'status': 'failed'},
        },
      });

      expect(state.hasPaidAccess, isFalse);
      expect(state.status, 'checkout_pending');
    });

    test('keeps checkout pending until backend confirms active access', () {
      final state = resolveCommercialAccessState({
        'commercial_access': {
          'status': 'checkout_pending',
          'has_paid_access': false,
          'access_is_active': false,
          'remaining_free_quotes': 0,
          'free_quotes_used': 1,
          'latest_payment': {'status': 'pending'},
        },
      });

      expect(state.hasPaidAccess, isFalse);
      expect(state.canReserve, isFalse);
      expect(state.status, 'checkout_pending');
      expect(state.quoteBlockedMessage, contains('checkout sigue abierto'));
    });

    test('marks expired access with reactivation messaging', () {
      final state = resolveCommercialAccessState({
        'commercial_access': {
          'status': 'expired',
          'expires_at': '2026-07-29',
          'has_paid_access': false,
        },
      });

      expect(state.isExpired, isTrue);
      expect(state.isConfirmedActive, isFalse);
      expect(state.canQuote, isFalse);
      expect(state.requiresPayment, isTrue);
      expect(state.accessBannerTitle, 'Acceso comercial vencido 29 julio 2026');
      expect(
        state.quoteBlockedMessage,
        'Tu acceso comercial vencio el 29 julio 2026. Reactiva el pago para continuar.',
      );
      expect(state.paymentActionLabel, 'Reactivar acceso comercial');
      expect(state.quoteActionLabel, 'Reactivar acceso comercial');
    });

    test('prefers access expiry from commercial access over payment dates', () {
      final state = resolveCommercialAccessState({
        'commercial_access': {
          'status': 'expired',
          'has_paid_access': true,
          'access_is_active': false,
          'access_is_expired': true,
          'access_expires_at': '2026-07-30',
          'available_actions': {
            'can_quote': false,
            'can_reserve': false,
            'can_renew': true,
          },
          'access_message':
              'Tu acceso ya expiró el 2026-07-30. Reactiva el pago para volver a cotizar, reservar, firmar contrato y pagar vuelos.',
          'latest_payment': {
            'status': 'paid',
            'billing_period_end': '2026-08-27',
          },
        },
      });

      expect(state.isExpired, isTrue);
      expect(state.canQuote, isFalse);
      expect(state.expiresAtLabel, '30 julio 2026');
      expect(state.quoteBlockedMessage, contains('Reactiva el pago'));
    });

    test('prefers backend access_expires_date over utc access_expires_at', () {
      final state = resolveCommercialAccessState({
        'commercial_access': {
          'status': 'expired',
          'has_paid_access': true,
          'access_is_active': false,
          'access_is_expired': true,
          'access_expires_at': '2026-07-30T05:50:59.000000Z',
          'access_expires_date': '2026-07-29',
          'access_expires_formatted': '2026-07-29',
          'available_actions': {
            'can_quote': false,
            'can_reserve': false,
            'can_renew': true,
          },
          'access_message':
              'Tu acceso ya expiró el 2026-07-29. Reactiva el pago para volver a cotizar, reservar, firmar contrato y pagar vuelos.',
          'latest_payment': {
            'status': 'paid',
            'billing_period_end': '2026-08-27',
          },
        },
      });

      expect(state.isExpired, isTrue);
      expect(state.canQuote, isFalse);
      expect(state.expiresAtLabel, '29 julio 2026');
      expect(state.accessBannerTitle, 'Acceso comercial vencido 29 julio 2026');
      expect(state.paymentActionLabel, 'Reactivar acceso comercial');
    });

    test('does not mark expired paid access as confirmed active', () {
      final state = resolveCommercialAccessState({
        'commercial_access': {
          'status': 'expired',
          'has_paid_access': true,
          'access_is_active': false,
          'access_is_expired': true,
          'access_expires_date': '2026-07-29',
          'available_actions': {
            'can_quote': false,
            'can_reserve': false,
            'can_renew': true,
          },
        },
      });

      expect(state.hasPaidAccess, isTrue);
      expect(state.isExpired, isTrue);
      expect(state.canReserve, isFalse);
      expect(state.isConfirmedActive, isFalse);
      expect(state.paymentActionLabel, 'Reactivar acceso comercial');
    });
  });
}
