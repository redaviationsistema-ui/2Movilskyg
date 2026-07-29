import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:red_sky/core/cliente_api.dart';

void main() {
  group('ApiClient fallback GET handling', () {
    test('retries alternative paths when a GET fallback returns 404', () async {
      final requestedPaths = <String>[];
      final client = ApiClient.forTesting(
        baseUrl: 'https://example.com',
        httpClient: MockClient((request) async {
          requestedPaths.add(request.url.path);

          if (request.url.path.endsWith('/payment-authorization')) {
            return http.Response(
              jsonEncode({'success': false, 'message': 'missing'}),
              404,
              headers: {'content-type': 'application/json'},
            );
          }

          if (request.url.path.endsWith('/autorizacion-pago')) {
            return http.Response(
              jsonEncode({'authorized': true, 'reservation_id': 32}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          return http.Response(
            jsonEncode({'message': 'unexpected path'}),
            500,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final payload = await client.getClientPaymentAuthorization(
        reservationId: '32',
      );

      expect(payload['authorized'], isTrue);
      expect(
        requestedPaths,
        containsAllInOrder([
          '/cliente/reservas/32/payment-authorization',
          '/cliente/reservas/32/autorizacion-pago',
        ]),
      );
    });

    test('retries alternative paths when the first GET returns 405', () async {
      final requestedPaths = <String>[];
      final client = ApiClient.forTesting(
        baseUrl: 'https://example.com',
        httpClient: MockClient((request) async {
          requestedPaths.add(request.url.path);

          if (request.url.path.endsWith('/payment-authorization')) {
            return http.Response(
              jsonEncode({'success': false, 'message': 'method not allowed'}),
              405,
              headers: {'content-type': 'application/json'},
            );
          }

          return http.Response(
            jsonEncode({'authorized': true, 'reservation_id': 32}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final payload = await client.getClientPaymentAuthorization(
        reservationId: '32',
      );

      expect(payload['authorized'], isTrue);
      expect(
        requestedPaths,
        containsAllInOrder([
          '/cliente/reservas/32/payment-authorization',
          '/cliente/reservas/32/autorizacion-pago',
        ]),
      );
    });

    test('does not swallow non-retriable GET errors', () async {
      final client = ApiClient.forTesting(
        baseUrl: 'https://example.com',
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'message': 'forbidden'}),
            403,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await expectLater(
        () => client.getClientPaymentAuthorization(reservationId: '32'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            403,
          ),
        ),
      );
    });

    test(
      'does not retry alternative paths on 500 for payment authorization',
      () async {
        final requestedPaths = <String>[];
        final client = ApiClient.forTesting(
          baseUrl: 'https://example.com',
          httpClient: MockClient((request) async {
            requestedPaths.add(request.url.path);
            return http.Response(
              jsonEncode({'message': 'server error'}),
              500,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        await expectLater(
          () => client.getClientPaymentAuthorization(reservationId: '32'),
          throwsA(
            isA<ApiException>().having(
              (error) => error.statusCode,
              'statusCode',
              500,
            ),
          ),
        );
        expect(requestedPaths, ['/cliente/reservas/32/payment-authorization']);
      },
    );
  });
}
