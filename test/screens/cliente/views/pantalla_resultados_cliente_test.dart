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
      auth.syncAccessState({
        'commercial_access': {'status': 'active', 'has_paid_access': true},
      });

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
      expect(find.textContaining('MMTO'), findsOneWidget);
      expect(find.textContaining('92 NM'), findsOneWidget);
      expect(find.textContaining('Incluido en la tarifa'), findsOneWidget);
      expect(find.textContaining('USD20'), findsOneWidget);
      expect(find.text('Base en origen'), findsNothing);
    },
  );

  testWidgets(
    'blocks request creation when quote is already unavailable and removes it from results',
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
      auth.syncAccessState({
        'commercial_access': {'status': 'active', 'has_paid_access': true},
      });

      reservation.quoteMatches = [
        {
          'id': 'match-1',
          'match_id': 'match-1',
          'aircraft': 'Learjet 45',
          'aircraft_id': 'aircraft-1',
          'is_available': false,
          'availability_reason': 'Esta aeronave ya no esta disponible.',
          'pricing': {'total_amount': 20787},
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

      await tester.ensureVisible(find.text('Crear solicitud'));
      await tester.tap(find.text('Crear solicitud'));
      await tester.pump();

      expect(reservation.quoteMatches, isEmpty);
      expect(find.text('Esta aeronave ya no esta disponible.'), findsOneWidget);
    },
  );

  testWidgets('shows selecting loading state when a quote card is tapped', (
    tester,
  ) async {
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
    auth.syncAccessState({
      'commercial_access': {'status': 'active', 'has_paid_access': true},
    });

    reservation.quoteMatches = [
      {
        'id': 'match-1',
        'match_id': 'match-1',
        'aircraft': 'Merlin III',
        'aircraft_id': 'aircraft-1',
        'pricing': {'total_amount': 25642},
        'category': 'Turboprop',
        'capacity': 8,
      },
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ReservationProvider>.value(value: reservation),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: const MaterialApp(home: ClientResultsScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Merlin III'));
    await tester.pump();

    expect(find.text('Seleccionando...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(reservation.selectedQuoteMatch?['match_id'], 'match-1');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
  });
}

class _MemorySessionStorage implements SessionStorage {
  @override
  Future<void> deleteToken() async {}

  @override
  Future<String?> readToken() async => null;

  @override
  Future<void> writeToken(String value) async {}
}
