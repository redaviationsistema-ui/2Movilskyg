import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:red_sky/core/auth/secure_session_storage.dart';
import 'package:red_sky/core/cliente_api.dart';
import 'package:red_sky/providers/proveedor_autenticacion.dart';
import 'package:red_sky/providers/proveedor_reservaciones.dart';
import 'package:red_sky/screens/cliente/views/pantalla_resultados_cliente.dart';

void main() {
  testWidgets(
    'renders repositioning details and uses pricing.total_amount as visible total',
    (tester) async {
      final reservation = ReservationProvider();
      final auth = AuthProvider(
        api: ApiClient.forTesting(
          baseUrl: 'https://api.example.test/api/v1',
          httpClient: MockClient((_) async => throw UnimplementedError()),
        ),
        sessionStorage: _MemorySessionStorage(),
      );
      addTearDown(reservation.dispose);
      addTearDown(auth.dispose);

      reservation.quoteMatches = [
        {
          'id': 'match-1',
          'aircraft': 'Learjet 45',
          'aircraft_id': 'aircraft-1',
          'status': 'available',
          'source_origin': 'MMTO',
          'requires_repositioning': true,
          'pricing': {'total_amount': 20787},
          'repositioning': {
            'origin_icao': 'MMTO',
            'destination_icao': 'MMQT',
            'distance_nm': 92,
            'flight_hours': 0.6,
          },
          'aircraft_base_airport': {'city': 'Toluca', 'icao': 'MMTO'},
        },
      ];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ReservationProvider>.value(
              value: reservation,
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ],
          child: const MaterialApp(home: ClientResultsScreen()),
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('Reposicionamiento desde TOLUCA'),
        findsOneWidget,
      );
      expect(find.text('MMTO -> MMQT'), findsOneWidget);
      expect(find.textContaining('92 NM'), findsOneWidget);
      expect(find.textContaining('Incluido en la tarifa'), findsOneWidget);
      expect(find.textContaining('USD 20787'), findsOneWidget);
      expect(find.text('Base en origen'), findsNothing);
    },
  );
}

class _MemorySessionStorage implements SessionStorage {
  @override
  Future<void> deleteToken() async {}

  @override
  Future<String?> readToken() async => null;

  @override
  Future<void> writeToken(String value) async {}
}
