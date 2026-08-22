import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:red_sky/core/cliente_api.dart';
import 'package:red_sky/core/client_workflow_status.dart';
import 'package:red_sky/models/aeronave.dart';
import 'package:red_sky/models/aeropuerto.dart';
import 'package:red_sky/providers/proveedor_reservaciones.dart';

void main() {
  group('ReservationProvider rememberCreatedFlightRequest', () {
    test(
      'defaults new request to provider pending when it was sent to provider',
      () {
        final provider = ReservationProvider();

        provider.rememberCreatedFlightRequest({
          'id': 'req_001',
          'provider_id': 'prov_001',
          'match_id': 'match_001',
        });

        expect(provider.flightRequests, isNotEmpty);
        final request = provider.flightRequests.first;

        expect(request['status'], 'reserved');
        expect(request['workflow_status'], 'reserva solicitada');
        expect(request['booking_status'], 'reserved');
        expect(request['next_action'], 'sent_to_provider');
        expect(resolveClientWorkflowStage(request), 'provider_pending');
      },
    );

    test('preserves backend workflow when it is explicitly provided', () {
      final provider = ReservationProvider();

      provider.rememberCreatedFlightRequest({
        'id': 'req_002',
        'provider_id': 'prov_002',
        'match_id': 'match_002',
        'status': 'provider_pending',
        'workflow_status': 'provider_pending',
      });

      expect(provider.flightRequests, isNotEmpty);
      final request = provider.flightRequests.first;

      expect(request['status'], 'provider_pending');
      expect(request['workflow_status'], 'provider_pending');
      expect(resolveClientWorkflowStage(request), 'provider_pending');
    });
  });

  test(
    'restoring a search keeps aircraft results and restores named airports',
    () {
      final provider = ReservationProvider();
      final aircraft = Aircraft.fromJson({
        'id': 'aircraft_550',
        'name': 'Cessna Citation II (550)',
        'aircraft_type': 'Light Jet',
        'capacity_passengers': 7,
      });
      final origin = Airport.fromJson({
        'name': 'Aeropuerto Internacional de Los Cabos',
        'iata': 'SJD',
        'icao': 'MMSD',
        'city': 'San José del Cabo',
      });
      final destination = Airport.fromJson({
        'name': 'Aeropuerto Internacional de Toluca',
        'iata': 'TLC',
        'icao': 'MMTO',
        'city': 'Toluca',
      });
      provider.aircraftFleet = [aircraft];
      provider.airports = [origin, destination];

      provider.restoreSearchDraft({
        'passengers': 1,
        'selected_aircraft_id': 'aircraft_550',
        'routes': [
          {
            'origin': 'MMSD',
            'destination': 'MMTO',
            'departure_datetime': '2026-07-27T15:30:00',
            'passengers': 1,
          },
        ],
      });

      expect(provider.aircraftFleet, contains(same(aircraft)));
      expect(provider.selectedAircraft, same(aircraft));
      expect(
        provider.routes.single.fromAirport?.name,
        'Aeropuerto Internacional de Los Cabos',
      );
      expect(
        provider.routes.single.toAirport?.name,
        'Aeropuerto Internacional de Toluca',
      );
    },
  );

  group('ReservationProvider flight history deduplication', () {
    test('TEST 1: same reservation_id merges into one record', () async {
      final provider = await _loadWorkspaceWithRows(
        requests: [
          _flightHistoryRow(
            reservationId: '39',
            flightRequestId: '201',
            requestNumber: 'REQ-201',
          ),
        ],
        reservations: [
          _flightHistoryRow(
            reservationId: '39',
            flightRequestId: '201',
            requestNumber: 'REQ-201',
          ),
        ],
      );

      expect(provider.flightRequests, hasLength(1));
    });

    test('TEST 2: same flight_request_id merges into one record', () async {
      final provider = await _loadWorkspaceWithRows(
        requests: [
          _flightHistoryRow(
            flightRequestId: '206',
            requestNumber: 'REQ-206',
            reservationId: null,
          ),
        ],
        reservations: [
          _flightHistoryRow(
            flightRequestId: '206',
            requestNumber: 'REQ-206',
            reservationId: null,
          ),
        ],
      );

      expect(provider.flightRequests, hasLength(1));
    });

    test(
      'TEST 3: different strong ids with same business key stay as two records',
      () async {
        final provider = await _loadWorkspaceWithRows(
          requests: [
            _flightHistoryRow(
              reservationId: '100',
              flightRequestId: '200',
              requestNumber: 'REQ-200',
            ),
          ],
          reservations: [
            _flightHistoryRow(
              reservationId: '101',
              flightRequestId: '201',
              requestNumber: 'REQ-201',
            ),
          ],
        );

        expect(provider.flightRequests, hasLength(2));
      },
    );

    test(
      'TEST 4: one row with ids and one without ids merges when business key matches',
      () async {
        final provider = await _loadWorkspaceWithRows(
          requests: [
            _flightHistoryRow(
              reservationId: null,
              flightRequestId: null,
              requestNumber: null,
            ),
          ],
          reservations: [
            _flightHistoryRow(
              reservationId: '39',
              flightRequestId: '201',
              requestNumber: 'REQ-201',
            ),
          ],
        );

        expect(provider.flightRequests, hasLength(1));
      },
    );

    test(
      'TEST 5: both rows without ids merge when business key matches',
      () async {
        final provider = await _loadWorkspaceWithRows(
          requests: [
            _flightHistoryRow(
              reservationId: null,
              flightRequestId: null,
              requestNumber: null,
            ),
          ],
          reservations: [
            _flightHistoryRow(
              reservationId: null,
              flightRequestId: null,
              requestNumber: null,
            ),
          ],
        );

        expect(provider.flightRequests, hasLength(1));
      },
    );

    test(
      'TEST 6: different business key without ids keeps separate records',
      () async {
        final provider = await _loadWorkspaceWithRows(
          requests: [
            _flightHistoryRow(
              reservationId: null,
              flightRequestId: null,
              requestNumber: null,
              destination: 'MMGL',
            ),
          ],
          reservations: [
            _flightHistoryRow(
              reservationId: null,
              flightRequestId: null,
              requestNumber: null,
              destination: 'MMAN',
            ),
          ],
        );

        expect(provider.flightRequests, hasLength(2));
      },
    );
  });
}

class _WorkspaceTestReservationProvider extends ReservationProvider {
  _WorkspaceTestReservationProvider({required super.apiClient});

  @override
  Future<void> loadInitialData() async {
    isLoadingData = false;
    notifyListeners();
  }
}

Future<ReservationProvider> _loadWorkspaceWithRows({
  required List<Map<String, dynamic>> requests,
  required List<Map<String, dynamic>> reservations,
}) async {
  final api = ApiClient.forTesting(
    baseUrl: 'https://api.example.test',
    httpClient: MockClient((request) async {
      final payload = switch (request.url.path) {
        '/cliente/dashboard' => <String, dynamic>{},
        '/client/flight-requests' => <String, dynamic>{
          'flight_requests': requests,
        },
        '/cliente/reservas' => <String, dynamic>{'reservations': reservations},
        '/client/aircraft' => <String, dynamic>{'data': []},
        _ => <String, dynamic>{'message': 'not found'},
      };
      final statusCode =
          request.url.path == '/cliente/dashboard' ||
                  request.url.path == '/client/flight-requests' ||
                  request.url.path == '/cliente/reservas' ||
                  request.url.path == '/client/aircraft'
              ? 200
              : 404;

      return http.Response(
        jsonEncode(payload),
        statusCode,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
  api.setToken('test-token');

  final provider = _WorkspaceTestReservationProvider(apiClient: api);
  addTearDown(provider.dispose);
  await provider.loadClientWorkspaceData(force: true);
  return provider;
}

Map<String, dynamic> _flightHistoryRow({
  String? reservationId = '39',
  String? flightRequestId = '201',
  String? requestNumber = 'REQ-201',
  String aircraftId = '12',
  String aircraftModel = 'HAWKER 800XPI',
  String origin = 'MMTO',
  String destination = 'MMAN',
  String departureDatetime = '2026-08-21T09:00:00.000000Z',
  int passengers = 3,
}) {
  return {
    if (reservationId != null) 'reservation_id': reservationId,
    if (flightRequestId != null) 'flight_request_id': flightRequestId,
    if (requestNumber != null) 'request_number': requestNumber,
    'assigned_aircraft_id': aircraftId,
    'assigned_aircraft_model': aircraftModel,
    'origin': origin,
    'destination': destination,
    'departure_datetime': departureDatetime,
    'passengers': passengers,
    'status': 'reserved',
    'workflow_status': 'provider_pending',
  };
}
