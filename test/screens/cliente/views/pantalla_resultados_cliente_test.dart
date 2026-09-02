import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:red_sky/core/auth/secure_session_storage.dart';
import 'package:red_sky/core/cliente_api.dart';
import 'package:red_sky/models/aeropuerto.dart';
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

  testWidgets('shows availability empty state only after a valid empty quote', (
    tester,
  ) async {
    final reservation =
        ReservationProvider()..quotePreviewState = QuotePreviewState.empty;
    final auth = _activeAuth();
    addTearDown(reservation.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(_resultsHarness(reservation, auth));

    expect(find.text('No encontramos aeronaves disponibles.'), findsOneWidget);
  });

  testWidgets(
    'does not show availability empty state for an idle reset draft',
    (tester) async {
      final reservation = ReservationProvider();
      final auth = _activeAuth();
      addTearDown(reservation.dispose);
      addTearDown(auth.dispose);

      await tester.pumpWidget(_resultsHarness(reservation, auth));

      expect(find.text('Completa tu itinerario.'), findsOneWidget);
      expect(find.text('No encontramos aeronaves disponibles.'), findsNothing);
    },
  );

  testWidgets(
    'successful creation closes results before its parent resets the draft',
    (tester) async {
      final api = _workspaceApi();
      final reservation = _TestReservationProvider(apiClient: api);
      final auth = _activeAuth();
      _seedQuotedDraft(reservation);
      addTearDown(reservation.dispose);
      addTearDown(auth.dispose);

      await tester.pumpWidget(_resultsNavigationHarness(reservation, auth));

      await tester.tap(find.text('Abrir resultados'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 pasajeros'), findsOneWidget);
      expect(find.textContaining('Toluca'), findsWidgets);
      expect(find.textContaining('Monterrey'), findsWidgets);
      expect(find.text('Ruta por confirmar'), findsNothing);
      await tester.tap(find.text('Crear solicitud'));
      await tester.pumpAndSettle();

      final harness = tester.state<_ResultsNavigationHarnessState>(
        find.byType(_ResultsNavigationHarness),
      );
      expect(harness.routeFinishedBeforeReset, isTrue);
      expect(reservation.passengers, 1);
      expect(reservation.quoteMatches, isEmpty);
      expect(reservation.flightRequests.single['id'], 'request-1');
    },
  );

  testWidgets(
    'a workspace sync failure after a successful post still closes results',
    (tester) async {
      var postCount = 0;
      final reservation = _TestReservationProvider(
        apiClient: _workspaceApi(
          onCreate: () {
            postCount += 1;
            return Future.value(_createdRequestResponse());
          },
        ),
        failWorkspaceSync: true,
      );
      final auth = _activeAuth();
      _seedQuotedDraft(reservation);
      addTearDown(reservation.dispose);
      addTearDown(auth.dispose);

      await tester.pumpWidget(_resultsNavigationHarness(reservation, auth));
      await tester.tap(find.text('Abrir resultados'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear solicitud'));
      await tester.pumpAndSettle();

      expect(postCount, 1);
      expect(reservation.flightRequests.single['id'], 'request-1');
      expect(find.text('Aeronaves disponibles'), findsNothing);
      expect(
        find.textContaining('No fue posible crear la solicitud'),
        findsNothing,
      );
      expect(reservation.passengers, 1);
    },
  );

  testWidgets('a failed post keeps results and the draft available for retry', (
    tester,
  ) async {
    final reservation = _TestReservationProvider(
      apiClient: _workspaceApi(
        onCreate:
            () => Future.value(
              _jsonResponse(422, {'message': 'Fecha no valida'}),
            ),
      ),
    );
    final auth = _activeAuth();
    _seedQuotedDraft(reservation);
    addTearDown(reservation.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(_resultsNavigationHarness(reservation, auth));
    await tester.tap(find.text('Abrir resultados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear solicitud'));
    await tester.pumpAndSettle();

    expect(find.text('Aeronaves disponibles'), findsOneWidget);
    expect(
      find.textContaining('No fue posible crear la solicitud'),
      findsOneWidget,
    );
    expect(reservation.passengers, 2);
    expect(reservation.routes.single.fromAirport?.icao, 'MMTO');
    expect(reservation.flightRequests, isEmpty);
  });

  testWidgets('double tap starts only one flight request creation', (
    tester,
  ) async {
    final requestCompleter = Completer<http.Response>();
    var postCount = 0;
    final api = _workspaceApi(
      onCreate: () {
        postCount += 1;
        return requestCompleter.future;
      },
    );
    final reservation = _TestReservationProvider(apiClient: api);
    final auth = _activeAuth();
    _seedQuotedDraft(reservation);
    addTearDown(reservation.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(_resultsHarness(reservation, auth));

    await tester.tap(find.text('Crear solicitud'));
    await tester.pump();
    await tester.tap(find.text('Creando solicitud...'));
    await tester.pump();

    expect(postCount, 1);
    requestCompleter.complete(_createdRequestResponse());
    await tester.pumpAndSettle();
  });
}

Widget _resultsHarness(ReservationProvider reservation, AuthProvider auth) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ReservationProvider>.value(value: reservation),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ],
      child: const MaterialApp(home: ClientResultsScreen()),
    );

Widget _resultsNavigationHarness(
  ReservationProvider reservation,
  AuthProvider auth,
) => MultiProvider(
  providers: [
    ChangeNotifierProvider<ReservationProvider>.value(value: reservation),
    ChangeNotifierProvider<AuthProvider>.value(value: auth),
  ],
  child: const MaterialApp(home: _ResultsNavigationHarness()),
);

AuthProvider _activeAuth() {
  final auth = AuthProvider(
    api: ApiClient.forTesting(
      baseUrl: 'https://api.example.test/api/v1',
      httpClient: MockClient((_) async => throw UnimplementedError()),
    ),
    sessionStorage: _MemorySessionStorage(),
  );
  auth.syncAccessState({
    'commercial_access': {'status': 'active', 'has_paid_access': true},
  });
  return auth;
}

ApiClient _workspaceApi({Future<http.Response> Function()? onCreate}) {
  final api = ApiClient.forTesting(
    baseUrl: 'https://api.example.test/api/v1',
    httpClient: MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path == '/api/v1/client/flight-requests') {
        return onCreate?.call() ?? _createdRequestResponse();
      }
      return _jsonResponse(200, switch (request.url.path) {
        '/api/v1/cliente/dashboard' => <String, dynamic>{},
        '/api/v1/client/flight-requests' => <String, dynamic>{
          'flight_requests': [
            {
              'id': 'request-1',
              'origin': 'MMTO',
              'destination': 'MMVA',
              'passengers': 2,
              'legs': [
                {'origin': 'MMTO', 'destination': 'MMVA', 'passengers': 2},
              ],
            },
          ],
        },
        '/api/v1/cliente/reservas' => <String, dynamic>{'reservations': []},
        '/api/v1/client/aircraft' => <String, dynamic>{'data': []},
        _ => <String, dynamic>{},
      });
    }),
  );
  api.setToken('test-token');
  return api;
}

http.Response _createdRequestResponse() => _jsonResponse(201, {
  'flight_request': {
    'id': 'request-1',
    'origin': 'MMTO',
    'destination': 'MMVA',
    'passengers': 2,
    'legs': [
      {'origin': 'MMTO', 'destination': 'MMVA', 'passengers': 2},
    ],
  },
});

http.Response _jsonResponse(int status, Map<String, dynamic> body) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void _seedQuotedDraft(ReservationProvider provider) {
  provider.passengers = 2;
  provider.routes.first
    ..fromAirport = _airport('Toluca', 'MMTO')
    ..toAirport = _airport('Monterrey', 'MMVA')
    ..startDate = DateTime(2027, 1, 2, 10);
  provider.quotePreviewState = QuotePreviewState.success;
  provider.quoteMatches = [
    {
      'id': 'match-1',
      'match_id': 'match-1',
      'aircraft_id': 'aircraft-1',
      'aircraft': 'Learjet 45',
      'pricing': {'total_amount': 20787},
    },
  ];
}

Airport _airport(String city, String icao) =>
    Airport(name: city, city: city, icao: icao, lat: 0, lng: 0);

class _TestReservationProvider extends ReservationProvider {
  _TestReservationProvider({
    required super.apiClient,
    this.failWorkspaceSync = false,
  });

  final bool failWorkspaceSync;

  @override
  Future<void> loadInitialData() async {}

  @override
  Future<void> loadClientWorkspaceData({bool force = false}) async {
    if (failWorkspaceSync) {
      throw StateError('workspace unavailable');
    }
    await super.loadClientWorkspaceData(force: force);
  }
}

class _ResultsNavigationHarness extends StatefulWidget {
  const _ResultsNavigationHarness();

  @override
  State<_ResultsNavigationHarness> createState() =>
      _ResultsNavigationHarnessState();
}

class _ResultsNavigationHarnessState extends State<_ResultsNavigationHarness> {
  bool routeFinishedBeforeReset = false;

  Future<void> _openResults() async {
    final requestId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ClientResultsScreen()),
    );
    if (!mounted) return;
    routeFinishedBeforeReset = true;
    context.read<ReservationProvider>().resetForm();
    if (requestId != null) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: _openResults,
        child: const Text('Abrir resultados'),
      ),
    ),
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
