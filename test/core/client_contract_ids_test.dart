import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:red_sky/core/cliente_api.dart';

void main() {
  test(
    'contract fallback always uses reservation ID, never flight request ID',
    () async {
      final paths = <String>[];
      final client = ApiClient.forTesting(
        baseUrl: 'https://example.test',
        httpClient: MockClient((r) async {
          paths.add(r.url.path);
          return http.Response(
            '{}',
            r.url.path.startsWith('/cliente/') ? 404 : 200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await client.getClientContract(
        reservationId: '900001',
        flightRequestId: '41',
      );
      expect(paths, [
        '/cliente/reservas/900001/contrato',
        '/client/reservations/900001/contract',
      ]);
    },
  );
  test(
    'resolves reservation relation through canonical flight request GET',
    () async {
      final paths = <String>[];
      final client = ApiClient.forTesting(
        baseUrl: 'https://example.test',
        httpClient: MockClient((r) async {
          paths.add(r.url.path);
          expect(r.method, 'GET');
          return http.Response(
            jsonEncode(
              r.url.path.endsWith('/41')
                  ? {
                    'flight_request': {
                      'id': 41,
                      'reservation': {'id': 900001},
                    },
                  }
                  : {
                    'contract': {'id': 73},
                  },
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await client.getClientContract(flightRequestId: '41');
      expect(paths, [
        '/client/flight-requests/41',
        '/cliente/reservas/900001/contrato',
      ]);
    },
  );
  test(
    'missing reservation relation does not guess or create a reservation',
    () async {
      final paths = <String>[];
      final client = ApiClient.forTesting(
        baseUrl: 'https://example.test',
        httpClient: MockClient((r) async {
          paths.add(r.url.path);
          return http.Response(
            '{"flight_request":{"id":41,"reservation":null}}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await expectLater(
        client.getClientContract(flightRequestId: '41'),
        throwsA(isA<ApiException>()),
      );
      expect(paths, ['/client/flight-requests/41']);
    },
  );
  test(
    'signature preserves canonical reservation ID over stale payload fields',
    () async {
      final client = ApiClient.forTesting(
        baseUrl: 'https://example.test',
        httpClient: MockClient((r) async {
          expect(r.url.path, '/cliente/reservas/900001/contrato/docusign');
          expect(jsonDecode(r.body)['reservation_id'], '900001');
          return http.Response(
            '{"envelope_id":"env-1"}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await client.sendClientContractForSignature(
        reservationId: '900001',
        flightRequestId: '41',
        contractPayload: {'reservation_id': '41'},
      );
    },
  );
}
