import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/core/replay_guard.dart';

void main() {
  test('repeated deep link is accepted only once', () {
    final guard = ReplayGuard();
    const link =
        'redsky://cliente/pago?session_id=cs_test_123&reservation_id=res-1';

    expect(guard.accept(link), isTrue);
    expect(guard.accept(link), isFalse);
  });

  test('a different return can be handled after the previous one', () {
    final guard = ReplayGuard();
    expect(guard.accept('redsky://cliente/pago?session_id=one'), isTrue);
    expect(guard.accept('redsky://cliente/pago?session_id=two'), isTrue);
  });
}
