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

        await provider.createFlightRequestForMatch(provider.quoteMatches.single);

        expect(capturedFlightRequestPayload, isNotNull);
        expect(capturedFlightRequestPayload!['total'], 14493);
        expect(capturedFlightRequestPayload!['final_price'], 14493);
        expect(
          (capturedFlightRequestPayload!['pricing_context'] as Map<String, dynamic>)['total_amount'],
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
                  'pricing': {
                    'billable_hours': 3.25,
                  },
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
