import 'dart:convert';
import 'dart:io';

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

  group('AuthProvider registerClient', () {
    test(
      'accepts alternative backend identity validation fields when registration is already verified',
      () async {
        final storage = MemorySessionStorage(null);
        final selfie = File(
          '${Directory.systemTemp.path}/auth_provider_register_client_verified_selfie.jpg',
        );
        await selfie.writeAsBytes(List<int>.filled(32, 1), flush: true);
        addTearDown(() async {
          if (await selfie.exists()) {
            await selfie.delete();
          }
        });

        final provider = AuthProvider(
          api: _api((request) async {
            expect(request.url.path, '/api/v1/auth/register');
            return _json(201, {
              'success': true,
              'token': 'register-token',
              'login_context': {'effective_role': 'client'},
              'user': {
                'id': 10,
                'name': 'Client',
                'email': 'client@example.test',
                'role': 'client',
                'requires_identity_validation': '1',
                'identity_verification_status': 'approved',
                'biometric_image_saved': true,
                'biometric_selfie_path': 'biometrics/selfies/client.jpg',
                'profile': {'document_number': 'ABC123456'},
              },
            });
          }),
          sessionStorage: storage,
        );

        final ok = await provider.registerClient(
          name: 'Client',
          email: 'client@example.test',
          phone: '+52 5555555555',
          password: 'Password123!',
          passwordConfirmation: 'Password123!',
          documentNumber: 'ABC123456',
          identityValidationRequired: true,
          selfieBiometric: selfie,
        );

        expect(ok, isTrue);
        expect(provider.errorMessage, isNull);
        expect(provider.isAuthenticated, isTrue);
        expect(storage.token, 'register-token');
      },
    );

    test(
      'fails closed when backend omits the persisted document number',
      () async {
        final storage = MemorySessionStorage(null);
        final provider = AuthProvider(
          api: _api((request) async {
            expect(request.url.path, '/api/v1/auth/register');
            return _json(201, {
              'success': true,
              'token': 'register-token',
              'login_context': {'effective_role': 'client'},
              'user': {
                'id': 8,
                'name': 'Client',
                'email': 'client@example.test',
                'role': 'client',
                'profile': {
                  'identity_validation_required': true,
                  'document_number': '',
                },
                'identity_verification_status': 'approved',
                'biometric_image_saved': true,
                'biometric_selfie_path': 'biometrics/selfies/client.jpg',
              },
            });
          }),
          sessionStorage: storage,
        );

        final ok = await provider.registerClient(
          name: 'Client',
          email: 'client@example.test',
          phone: '+52 5555555555',
          password: 'Password123!',
          passwordConfirmation: 'Password123!',
          documentNumber: 'ABC123456',
          identityValidationRequired: true,
        );

        expect(ok, isFalse);
        expect(
          provider.errorMessage,
          'El backend no confirmo el numero de documento guardado en el perfil.',
        );
        expect(provider.isAuthenticated, isFalse);
        expect(storage.token, isNull);
      },
    );

    test(
      'fails closed when backend omits the saved biometric selfie reference',
      () async {
        final storage = MemorySessionStorage(null);
        final selfie = File(
          '${Directory.systemTemp.path}/auth_provider_register_client_selfie.jpg',
        );
        await selfie.writeAsBytes(List<int>.filled(32, 1), flush: true);
        addTearDown(() async {
          if (await selfie.exists()) {
            await selfie.delete();
          }
        });

        final provider = AuthProvider(
          api: _api((request) async {
            expect(request.url.path, '/api/v1/auth/register');
            return _json(201, {
              'success': true,
              'token': 'register-token',
              'login_context': {'effective_role': 'client'},
              'user': {
                'id': 9,
                'name': 'Client',
                'email': 'client@example.test',
                'role': 'client',
                'profile': {
                  'identity_validation_required': true,
                  'document_number': 'ABC123456',
                },
                'identity_verification_status': 'approved',
                'biometric_image_saved': true,
                'biometric_selfie_path': '',
                'biometric_selfie_url': '',
              },
            });
          }),
          sessionStorage: storage,
        );

        final ok = await provider.registerClient(
          name: 'Client',
          email: 'client@example.test',
          phone: '+52 5555555555',
          password: 'Password123!',
          passwordConfirmation: 'Password123!',
          documentNumber: 'ABC123456',
          identityValidationRequired: true,
          selfieBiometric: selfie,
        );

        expect(ok, isFalse);
        expect(
          provider.errorMessage,
          'El backend no devolvio la referencia de la selfie biometrica guardada.',
        );
        expect(provider.isAuthenticated, isFalse);
        expect(storage.token, isNull);
      },
    );
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
