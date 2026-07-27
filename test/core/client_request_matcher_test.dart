import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/core/client_request_matcher.dart';

void main() {
  final requests = [
    {'id': 'request-1', 'reservation_id': 'reservation-1'},
    {
      'id': 'request-2',
      'reservation': {'id': 'reservation-2'},
    },
  ];

  test('finds only an exact request or reservation id', () {
    expect(
      findClientRequestByExactId(requests, 'reservation-2')?['id'],
      'request-2',
    );
  });

  test('missing request fails closed instead of returning first', () {
    expect(findClientRequestByExactId(requests, 'reservation-other'), isNull);
    expect(findClientRequestByExactId(requests, null), isNull);
  });

  test('reservation owned by another user fails ownership validation', () {
    expect(
      clientOwnsReservationPayload({
        'reservation': {'id': 'reservation-1', 'client_id': 'user-other'},
      }, 'user-current'),
      isFalse,
    );
    expect(
      clientOwnsReservationPayload({
        'reservation': {'id': 'reservation-1', 'client_id': 'user-current'},
      }, 'user-current'),
      isTrue,
    );
  });
}
