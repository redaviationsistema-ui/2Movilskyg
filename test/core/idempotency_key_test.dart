import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:red_sky/core/cliente_api.dart';
import 'package:red_sky/core/idempotency_key.dart';

void main() {
  test('same operation and request produce same key after process retry', () {
    final first = IdempotencyKey.forOperation(
      'create-reservation',
      'REQUEST-123',
    );
    final retry = IdempotencyKey.forOperation(
      'create-reservation',
      'request-123',
    );

    expect(retry, first);
    expect(first, startsWith('mobile-create-reservation-'));
  });

  test('different operations do not share an idempotency key', () {
    expect(
      IdempotencyKey.forOperation('create-reservation', 'request-123'),
      isNot(IdempotencyKey.forOperation('create-checkout', 'request-123')),
    );
  });

  test('reservation retries send the same idempotency header', () async {
    final observedKeys = <String>[];
    final api = ApiClient.forTesting(
      baseUrl: 'https://example.test/api/v1',
      httpClient: MockClient((request) async {
        observedKeys.add(request.headers['Idempotency-Key'] ?? '');
        return http.Response(
          jsonEncode({'reservation_id': 'reservation-1'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    )..setToken('token');

    final first = await api.createClientReservation(
      flightRequestId: 'request-1',
    );
    final retry = await api.createClientReservation(
      flightRequestId: 'request-1',
    );

    expect(first['reservation_id'], retry['reservation_id']);
    expect(observedKeys, hasLength(2));
    expect(observedKeys.first, isNotEmpty);
    expect(observedKeys.last, observedKeys.first);
  });
}
