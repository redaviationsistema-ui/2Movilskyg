import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:red_sky/core/cliente_api.dart';
import 'package:red_sky/screens/sobrecargo/pantalla_espacio_sobrecargo.dart';

void main() {
  testWidgets('Crew notifications load unread count on mount', (tester) async {
    var requests = 0;
    final api = ApiClient.forTesting(
      baseUrl: 'https://api.example.test/api/v1',
      httpClient: MockClient((request) async {
        requests++;
        expect(request.url.path, '/api/v1/notifications');
        return http.Response(
          jsonEncode({
            'unread_count': 2,
            'notifications': {
              'data': [
                {
                  'id': 1,
                  'title': 'Nueva misión',
                  'message': 'Revisa tu asignación',
                  'read_at': null,
                },
                {
                  'id': 2,
                  'title': 'Cambio operativo',
                  'message': 'Se actualizó la hora',
                  'read_at': null,
                },
              ],
            },
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: CrewNotificationsView(api: api))),
    );
    await tester.pumpAndSettle();

    expect(requests, 1);
    expect(find.text('2 sin leer'), findsOneWidget);
    expect(find.text('Nueva misión'), findsOneWidget);
  });
}
