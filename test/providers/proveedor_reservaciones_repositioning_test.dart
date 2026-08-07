import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:red_sky/core/cliente_api.dart';
import 'package:red_sky/models/aeropuerto.dart';
import 'package:red_sky/providers/proveedor_reservaciones.dart';

void main() {
  group('ReservationProvider preview repositioning', () {
    test(
      'preserves backend repositioned matches and official pricing total_amount',
      () async {
        final provider = ReservationProvider(
          apiClient: _api((request) async {
            expect(request.url.path, '/api/v1/client/quotes/preview');
            return _json(200, {
              'matches': [
                {
                  'id': 'match-1',
                  'aircraft_id': 'aircraft-1',
                  'aircraft_name': 'Learjet 45',
                  'status': 'available',
                  'source_origin': 'MMTO',
                  'requires_repositioning': true,
                  'selected_radius_nm': '200',
                  'aircraft_base_airport': {'icao': 'MMTO', 'city': 'Toluca'},
                  'repositioning': {
                    'origin_icao': 'MMTO',
                    'destination_icao': 'MMQT',
                    'distance_nm': '92',
                    'flight_hours': '0.6',
                  },
                  'pricing': {
                    'total_amount': '20787',
                    'customer_flight_cost': '15000',
                  },
                },
              ],
            });
          }),
        );
        addTearDown(provider.dispose);

        provider.routes.first
          ..fromAirport = _airport('Queretaro', 'MMQT', 'QRO')
          ..toAirport = _airport('Monterrey', 'MMMY', 'MTY')
          ..startDate = DateTime(2026, 8, 2, 10);
        provider.passengers = 4;

        final success = await provider.previewCurrentSelection();

        expect(success, isTrue);
        expect(provider.quoteMatches, hasLength(1));
        expect(provider.quoteMatches.single['requires_repositioning'], isTrue);
        expect(provider.quoteMatches.single['selected_radius_nm'], 200);
        expect(provider.quoteMatches.single['pricing']['total_amount'], 20787);
        expect(provider.quoteMatches.single['total'], 20787);
        expect(
          provider.quoteMatches.single['repositioning']['distance_nm'],
          '92',
        );
      },
    );

    test(
      'prefers pricing.total_amount over stale top-level totals in card and persisted request payload',
      () async {
        Map<String, dynamic>? capturedFlightRequestPayload;
        final provider = ReservationProvider(
          apiClient: _api((request) async {
            if (request.url.path == '/api/v1/client/quotes/preview') {
              return _json(200, {
                'matches': [
                  {
                    'id': 'match-hawker',
                    'match_id': 'match-hawker',
                    'aircraft_id': 'aircraft-hawker',
                    'aircraft_name': 'HAWKER 800A',
                    'status': 'available',
                    'total': 13535,
                    'pricing': {
                      'total_amount': 14493,
                      'customer_flight_cost': 10000,
                      'repositioning_cost': 1200,
                      'return_to_base_cost': 800,
                      'airport_expenses': 300,
                      'overnight_cost': 0,
                      'margin_amount': 1200,
                      'payment_fees': 493,
                      'taxes': 500,
                    },
                  },
                ],
              });
            }

            if (request.url.path == '/api/v1/client/flight-requests') {
              capturedFlightRequestPayload =
                  jsonDecode(request.body) as Map<String, dynamic>;
              return _json(200, {
                'flight_request': {
                  'id': 'req-hawker',
                  'match_id': 'match-hawker',
                  'total_amount': 14493,
                },
              });
            }

            throw StateError('Unexpected path ${request.url.path}');
          }),
        );
        addTearDown(provider.dispose);

        provider.routes.first
          ..fromAirport = _airport('Aguascalientes', 'MMAS', 'AGU')
          ..toAirport = _airport('Guadalajara', 'MMGL', 'GDL')
          ..startDate = DateTime(2026, 8, 2, 10);
        provider.passengers = 4;

        final success = await provider.previewCurrentSelection();

        expect(success, isTrue);
        expect(provider.quoteMatches, hasLength(1));
        expect(provider.quoteMatches.single['pricing']['total_amount'], 14493);
        expect(provider.quoteMatches.single['total'], 14493);

        await provider.createFlightRequestForMatch(
          provider.quoteMatches.single,
        );

        expect(capturedFlightRequestPayload, isNotNull);
        expect(capturedFlightRequestPayload!['total'], 14493);
        expect(capturedFlightRequestPayload!['final_price'], 14493);
        expect(
          (capturedFlightRequestPayload!['pricing_context']
              as Map<String, dynamic>)['total_amount'],
          14493,
        );
      },
    );

    test(
      'prefers selected_card_price over stale total and keeps direct flight time for cards',
      () async {
        final provider = ReservationProvider(
          apiClient: _api((request) async {
            expect(request.url.path, '/api/v1/client/quotes/preview');
            return _json(200, {
              'matches': [
                {
                  'id': 'match-display-price',
                  'aircraft_id': 'aircraft-display-price',
                  'aircraft_name': 'HAWKER 800A',
                  'status': 'available',
                  'total': 13535,
                  'selected_card_price': 14493,
                  'time': '45 min',
                  'pricing': {'billable_hours': 3.25},
                },
              ],
            });
          }),
        );
        addTearDown(provider.dispose);

        provider.routes.first
          ..fromAirport = _airport('Aguascalientes', 'MMAS', 'AGU')
          ..toAirport = _airport('Guadalajara', 'MMGL', 'GDL')
          ..startDate = DateTime(2026, 8, 2, 10);
        provider.passengers = 1;

        final success = await provider.previewCurrentSelection();

        expect(success, isTrue);
        expect(provider.quoteMatches, hasLength(1));
        expect(provider.quoteMatches.single['total'], 14493);
        expect(provider.quoteMatches.single['time'], '45 min');
      },
    );

    test(
      'preserves normalized backend billable hours in preview matches when pricing and breakdown diverge',
      () async {
        final provider = ReservationProvider(
          apiClient: _api((request) async {
            expect(request.url.path, '/api/v1/client/quotes/preview');
            return _json(200, {
              'matches': [
                {
                  'id': 'match-g4',
                  'match_id': 'match-g4',
                  'aircraft_id': 'aircraft-g4',
                  'aircraft_name': 'GULFSTREAM G-IV',
                  'status': 'available',
                  'billable_hours': 3.28,
                  'pricing': {'total_amount': 47700},
                  'pricing_breakdown': {
                    'display_route_hours': 3.28,
                    'final_billable_hours': 4.17,
                    'billable_hours': 6.10,
                    'route_billable_hours': 3.28,
                  },
                },
              ],
            });
          }),
        );
        addTearDown(provider.dispose);

        provider.routes.first
          ..fromAirport = _airport('Toluca', 'MMTO', 'TLC')
          ..toAirport = _airport('Guaymas', 'MMGM', 'GYM')
          ..startDate = DateTime(2026, 8, 3, 9);
        provider.passengers = 8;

        final success = await provider.previewCurrentSelection();

        expect(success, isTrue);
        expect(provider.quoteMatches, hasLength(1));
        expect(provider.quoteMatches.single['time'], '3 h 17 min');
        expect(provider.quoteMatches.single['final_billable_hours'], 4.17);
        expect(provider.quoteMatches.single['billable_hours'], 6.1);
        expect(provider.quoteMatches.single['route_billable_hours'], 3.28);
        expect(
          (provider.quoteMatches.single['debug_pricing']
              as Map<String, dynamic>)['final_billable_hours'],
          4.17,
        );
      },
    );

    test(
      'sends closed two-leg itineraries as round trip with the selected return date',
      () async {
        Map<String, dynamic>? capturedPreviewPayload;
        final provider = ReservationProvider(
          apiClient: _api((request) async {
            if (request.url.path == '/api/v1/client/quotes/preview') {
              capturedPreviewPayload =
                  jsonDecode(request.body) as Map<String, dynamic>;
              return _json(200, {'matches': []});
            }
            throw StateError('Unexpected path ${request.url.path}');
          }),
        );
        addTearDown(provider.dispose);

        provider.setBookingTripLabel('Ida y vuelta');
        provider.routes.first
          ..fromAirport = _airport('Toluca', 'MMTO', 'TLC')
          ..toAirport = _airport('Guaymas', 'MMGM', 'GYM')
          ..startDate = DateTime(2026, 8, 3, 9);
        provider.passengers = 8;
        provider.addRoute(allowIncomplete: true);
        provider.routes[1]
          ..fromAirport = _airport('Guaymas', 'MMGM', 'GYM')
          ..toAirport = _airport('Toluca', 'MMTO', 'TLC')
          ..startDate = DateTime(2026, 8, 6, 9);

        await provider.previewCurrentSelection();

        expect(capturedPreviewPayload, isNotNull);
        expect(capturedPreviewPayload!['flight_base_source'], 'pricing_trip_hours');
        expect(capturedPreviewPayload!['trip_type'], 'round_trip');
        expect(capturedPreviewPayload!['close_route'], isTrue);
        expect(capturedPreviewPayload!['open_route'], isFalse);
        expect(capturedPreviewPayload!['return_to_origin'], isTrue);
        expect(capturedPreviewPayload!['return_date'], '2026-08-06');
        expect(
          capturedPreviewPayload!['return_datetime'],
          '2026-08-06T09:00:00',
        );
      },
    );

    test(
      'promotes official display route hours over stale trip labels when normalizing preview matches',
      () async {
        final provider = ReservationProvider(
          apiClient: _api((request) async {
            expect(request.url.path, '/api/v1/client/quotes/preview');
            return _json(200, {
              'matches': [
                {
                  'id': 'match-visible-time',
                  'aircraft_id': 'aircraft-visible-time',
                  'aircraft_name': 'LEARJET 45',
                  'trip_time': '4 h 50 min',
                  'card_time': '4 h 50 min',
                  'time': '4 h 50 min',
                  'pricing': {
                    'display_route_hours': 1.83,
                    'total_amount': 18874,
                  },
                },
              ],
            });
          }),
        );
        addTearDown(provider.dispose);

        provider.routes.first
          ..fromAirport = _airport('Toluca', 'MMTO', 'TLC')
          ..toAirport = _airport('Guaymas', 'MMGM', 'GYM')
          ..startDate = DateTime(2026, 8, 3, 9);
        provider.passengers = 4;

        final success = await provider.previewCurrentSelection();

        expect(success, isTrue);
        expect(provider.quoteMatches, hasLength(1));
        expect(provider.quoteMatches.single['display_route_hours'], 1.83);
        expect(provider.quoteMatches.single['time'], '1 h 50 min');
        expect(provider.quoteMatches.single['trip_time'], '1 h 50 min');
        expect(provider.quoteMatches.single['card_time'], '1 h 50 min');
        expect(
          (provider.quoteMatches.single['pricing_breakdown']
              as Map<String, dynamic>)['display_route_hours'],
          1.83,
        );
      },
    );

    test(
      'persists normalized backend billable hours when creating a flight request',
      () async {
        Map<String, dynamic>? capturedFlightRequestPayload;
        final provider = ReservationProvider(
          apiClient: _api((request) async {
            if (request.url.path == '/api/v1/client/quotes/preview') {
              return _json(200, {
                'matches': [
                  {
                    'id': 'match-g4-request',
                    'match_id': 'match-g4-request',
                    'aircraft_id': 'aircraft-g4-request',
                    'aircraft_name': 'GULFSTREAM G-IV',
                    'status': 'available',
                    'billable_hours': 3.28,
                    'pricing': {'total_amount': 47700},
                    'pricing_breakdown': {
                      'final_billable_hours': 4.17,
                      'billable_hours': 6.10,
                      'route_billable_hours': 3.28,
                    },
                  },
                ],
              });
            }

            if (request.url.path == '/api/v1/client/flight-requests') {
              capturedFlightRequestPayload =
                  jsonDecode(request.body) as Map<String, dynamic>;
              return _json(200, {
                'flight_request': {
                  'id': 'req-g4-request',
                  'match_id': 'match-g4-request',
                  'total_amount': 47700,
                },
              });
            }

            throw StateError('Unexpected path ${request.url.path}');
          }),
        );
        addTearDown(provider.dispose);

        provider.routes.first
          ..fromAirport = _airport('Toluca', 'MMTO', 'TLC')
          ..toAirport = _airport('Guaymas', 'MMGM', 'GYM')
          ..startDate = DateTime(2026, 8, 3, 9);
        provider.passengers = 8;

        final success = await provider.previewCurrentSelection();

        expect(success, isTrue);
        await provider.createFlightRequestForMatch(
          provider.quoteMatches.single,
        );

        expect(capturedFlightRequestPayload, isNotNull);
        expect(capturedFlightRequestPayload!['billable_hours'], 6.1);
        expect(capturedFlightRequestPayload!['final_billable_hours'], 4.17);
        expect(capturedFlightRequestPayload!['route_billable_hours'], 3.28);
        expect(
          capturedFlightRequestPayload!['time_display_mode'],
          'operational',
        );
        expect(
          capturedFlightRequestPayload!['billing_hours_mode'],
          'operational',
        );
        expect(
          (capturedFlightRequestPayload!['aircraft_snapshot']
              as Map<String, dynamic>)['final_billable_hours'],
          4.17,
        );
      },
    );

    test('keeps backend order when preview returns multiple matches', () async {
      final provider = ReservationProvider(
        apiClient: _api((_) async {
          return _json(200, {
            'matches': [
              {
                'id': 'match-expensive-first',
                'aircraft_id': 'aircraft-10',
                'aircraft_name': 'Jet A',
                'status': 'available',
                'source_origin': 'MMQT',
                'pricing': {'total_amount': 30000},
              },
              {
                'id': 'match-cheaper-second',
                'aircraft_id': 'aircraft-20',
                'aircraft_name': 'Jet B',
                'status': 'available',
                'source_origin': 'MMTO',
                'pricing': {'total_amount': 15000},
              },
            ],
          });
        }),
      );
      addTearDown(provider.dispose);

      provider.routes.first
        ..fromAirport = _airport('Queretaro', 'MMQT', 'QRO')
        ..toAirport = _airport('Monterrey', 'MMMY', 'MTY')
        ..startDate = DateTime(2026, 8, 2, 10);

      final success = await provider.previewCurrentSelection();

      expect(success, isTrue);
      expect(provider.quoteMatches.map((item) => item['id']).toList(), [
        'match-expensive-first',
        'match-cheaper-second',
      ]);
    });

    test('maps timeout errors to a specific user-facing message', () async {
      final provider = ReservationProvider(
        apiClient: _api((_) async {
          throw TimeoutException('slow');
        }),
      );
      addTearDown(provider.dispose);

      provider.routes.first
        ..fromAirport = _airport('Queretaro', 'MMQT', 'QRO')
        ..toAirport = _airport('Monterrey', 'MMMY', 'MTY')
        ..startDate = DateTime(2026, 8, 2, 10);

      final success = await provider.previewCurrentSelection();

      expect(success, isFalse);
      expect(
        provider.quoteError,
        'El servidor tardó demasiado en responder. Intenta nuevamente en unos momentos.',
      );
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

Airport _airport(String city, String icao, String iata) =>
    Airport(name: city, city: city, icao: icao, iata: iata, lat: 0, lng: 0);
