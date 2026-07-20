import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:red_sky/core/auth/secure_session_storage.dart';
import 'package:red_sky/core/cliente_api.dart';
import 'package:red_sky/providers/proveedor_autenticacion.dart';

void main() {
  group('AuthProvider bootstrap', () {
    test(
      'restores a client session from the canonical effective role',
      () async {
        final storage = MemorySessionStorage('valid-token');
        final api = _api((request) async {
          expect(request.url.path, '/api/v1/auth/me');
          expect(request.headers['authorization'], 'Bearer valid-token');
          return _json(200, _sessionPayload('client'));
        });
        final provider = AuthProvider(api: api, sessionStorage: storage);

        await provider.bootstrapSession();

        expect(provider.bootstrapState, SessionBootstrapState.authenticated);
        expect(provider.role, AppUserRole.client);
        expect(provider.user?.email, 'client@example.test');
        expect(storage.token, 'valid-token');
      },
    );

    test('invalid token clears the persisted session', () async {
      final storage = MemorySessionStorage('expired-token');
      final provider = AuthProvider(
        api: _api((_) async => _json(401, {'message': 'Unauthenticated.'})),
        sessionStorage: storage,
      );

      await provider.bootstrapSession();

      expect(provider.bootstrapState, SessionBootstrapState.signedOut);
      expect(provider.role, AppUserRole.unknown);
      expect(storage.token, isNull);
    });

    test(
      'network failure preserves the persisted token and does not infer role',
      () async {
        final storage = MemorySessionStorage('offline-token');
        final provider = AuthProvider(
          api: _api((_) async => throw http.ClientException('offline')),
          sessionStorage: storage,
        );

        await provider.bootstrapSession();

        expect(provider.bootstrapState, SessionBootstrapState.offline);
        expect(provider.role, AppUserRole.unknown);
        expect(storage.token, 'offline-token');
      },
    );

    test('unknown effective role fails closed', () async {
      final storage = MemorySessionStorage('valid-token');
      final provider = AuthProvider(
        api: _api((_) async => _json(200, _sessionPayload('invented-role'))),
        sessionStorage: storage,
      );

      await provider.bootstrapSession();

      expect(provider.bootstrapState, SessionBootstrapState.denied);
      expect(provider.role, AppUserRole.unknown);
      expect(provider.isAuthenticated, isFalse);
      expect(storage.token, isNull);
    });
  });
}

ApiClient _api(MockClientHandler handler) => ApiClient.forTesting(
  baseUrl: 'https://api.example.test/api/v1',
  httpClient: MockClient(handler),
);

http.Response _json(int status, Map<String, dynamic> payload) => http.Response(
  jsonEncode(payload),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _sessionPayload(String role) => {
  'success': true,
  'user': {
    'id': 7,
    'name': 'Client',
    'email': 'client@example.test',
    'role': 'client',
  },
  'login_context': {'effective_role': role},
};

class MemorySessionStorage implements SessionStorage {
  MemorySessionStorage(this.token);

  String? token;

  @override
  Future<void> deleteToken() async => token = null;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String value) async => token = value;
}
