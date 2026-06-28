import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/core/acceso_comercial_cliente.dart';

void main() {
  group('commercial access payment records', () {
    test('activates access from a paid latest_payment record', () {
      final state = resolveCommercialAccessState({
        'commercial_access': {
          'status': 'payment_pending',
          'has_paid_access': false,
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
            'status': 'payment_pending',
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
      expect(state.status, 'payment_pending');
    });
  });
}
