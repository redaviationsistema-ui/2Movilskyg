import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:red_sky/core/cliente_api.dart';
import 'package:red_sky/models/aeropuerto.dart';
import 'package:red_sky/providers/proveedor_reservaciones.dart';

void main() {
  group('ReservationProvider availability normalization', () {
    test(
      'preserves boolean and nullable availability fields from backend matches',
      () async {
        final provider = ReservationProvider(
          apiClient: _api((request) async {
            expect(request.url.path, '/api/v1/client/quotes/preview');
            return _json(200, {
              'matches': [
                {
                  'id': 'match-true',
                  'aircraft_id': 'aircraft-true',
                  'aircraft_name': 'Aircraft True',
                  'is_available': true,
                  'availability_status': 'available',
                  'availability_reason': null,
                  'pricing': {'total_amount': 12000},
                },
                {
                  'id': 'match-false',
                  'aircraft_id': 'aircraft-false',
                  'aircraft_name': 'Aircraft False',
                  'is_available': false,
                  'availability_status': 'unavailable',
                  'availability_reason': 'Aircraft already reserved',
                  'pricing': {'total_amount': 13000},
                },
                {
                  'id': 'match-null',
                  'aircraft_id': 'aircraft-null',
                  'aircraft_name': 'Aircraft Null',
                  'is_available': null,
                  'availability_status': null,
                  'availability_reason': null,
                  'pricing': {'total_amount': 14000},
                },
              ],
            });
          }),
        );
        addTearDown(provider.dispose);
        _seedValidQuoteRequest(provider);

        final success = await provider.previewCurrentSelection();

        expect(success, isTrue);
        expect(provider.quoteMatches, hasLength(3));
        expect(provider.quoteMatches[0]['is_available'], isTrue);
        expect(provider.quoteMatches[0]['availability_status'], 'available');
        expect(provider.quoteMatches[1]['is_available'], isFalse);
        expect(provider.quoteMatches[1]['availability_status'], 'unavailable');
        expect(
          provider.quoteMatches[1]['availability_reason'],
          'Aircraft already reserved',
        );
        expect(provider.quoteMatches[2]['is_available'], isNull);
        expect(provider.quoteMatches[2]['availability_status'], isNull);
        expect(provider.quoteMatches[2]['availability_reason'], isNull);
      },
    );

    test(
      'treats non-boolean availability inputs as unknown instead of coercing them',
      () async {
        final provider = ReservationProvider(
          apiClient: _api((request) async {
            expect(request.url.path, '/api/v1/client/quotes/preview');
            return _json(200, {
              'matches': [
                {
                  'id': 'match-string-false',
                  'aircraft_id': 'aircraft-string-false',
                  'aircraft_name': 'Aircraft String False',
                  'is_available': 'false',
                  'pricing': {'total_amount': 12000},
                },
                {
                  'id': 'match-string-true',
                  'aircraft_id': 'aircraft-string-true',
                  'aircraft_name': 'Aircraft String True',
                  'is_available': 'true',
                  'pricing': {'total_amount': 13000},
                },
                {
                  'id': 'match-int-one',
                  'aircraft_id': 'aircraft-int-one',
                  'aircraft_name': 'Aircraft Int One',
                  'is_available': 1,
                  'pricing': {'total_amount': 14000},
                },
                {
                  'id': 'match-int-zero',
                  'aircraft_id': 'aircraft-int-zero',
                  'aircraft_name': 'Aircraft Int Zero',
                  'is_available': 0,
                  'pricing': {'total_amount': 15000},
                },
                {
                  'id': 'match-missing',
                  'aircraft_id': 'aircraft-missing',
                  'aircraft_name': 'Aircraft Missing',
                  'pricing': {'total_amount': 16000},
                },
              ],
            });
          }),
        );
        addTearDown(provider.dispose);
        _seedValidQuoteRequest(provider);

        final success = await provider.previewCurrentSelection();

        expect(success, isTrue);
        expect(provider.quoteMatches, hasLength(5));
        for (final match in provider.quoteMatches) {
          expect(
            match['is_available'],
            isNull,
            reason: 'Unexpected coercion for ${match['id']}',
          );
        }
      },
    );

    test(
      'a fresh quote can reintroduce an aircraft after a previous availability conflict',
      () async {
        var previewCall = 0;
        final provider = ReservationProvider(
          apiClient: _api((request) async {
            expect(request.url.path, '/api/v1/client/quotes/preview');
            previewCall += 1;
            return _json(200, {
              'matches': [
                {
                  'id': 'match-aircraft-1-v$previewCall',
                  'aircraft_id': 'aircraft-1',
                  'aircraft_name': 'Learjet 45',
                  'is_available': true,
                  'pricing': {'total_amount': 20000 + previewCall},
                },
                {
                  'id': 'match-aircraft-2-v$previewCall',
                  'aircraft_id': 'aircraft-2',
                  'aircraft_name': 'Hawker 800',
                  'is_available': true,
                  'pricing': {'total_amount': 21000 + previewCall},
                },
              ],
            });
          }),
        );
        addTearDown(provider.dispose);
        _seedValidQuoteRequest(provider);

        final firstSuccess = await provider.previewCurrentSelection();
        expect(firstSuccess, isTrue);
        expect(provider.quoteMatches, hasLength(2));

        provider.handleAircraftUnavailable({
          'aircraft_id': 'aircraft-1',
          'match_id': 'match-aircraft-1-v1',
        });

        expect(
          provider.quoteMatches.map((quote) => quote['aircraft_id']).toList(),
          ['aircraft-2'],
        );

        final secondSuccess = await provider.previewCurrentSelection();

        expect(secondSuccess, isTrue);
        expect(
          provider.quoteMatches.map((quote) => quote['aircraft_id']).toList(),
          ['aircraft-1', 'aircraft-2'],
        );
      },
    );
  });
}

void _seedValidQuoteRequest(ReservationProvider provider) {
  provider.routes.first
    ..fromAirport = _airport('Toluca', 'MMTO', 'TLC')
    ..toAirport = _airport('Monterrey', 'MMMY', 'MTY')
    ..startDate = DateTime(2026, 8, 20, 10);
  provider.passengers = 4;
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
