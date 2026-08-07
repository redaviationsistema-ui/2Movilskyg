import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/screens/cliente/views/pantalla_confirmacion_reserva_cliente.dart';

void main() {
  testWidgets('muestra todos los tramos con su fecha en la confirmacion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClientBookingConfirmationScreen(
          request: {
            'passengers': 2,
            'legs': [
              {
                'origin': 'MMTO',
                'destination': 'MMIA',
                'departure_datetime': '2026-08-10T09:30:00',
              },
              {
                'origin': 'MMIA',
                'destination': 'MMTO',
                'departure_datetime': '2026-08-12T17:45:00',
              },
            ],
          },
          onOpenTrips: () {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('MMTO  →  MMIA'), findsOneWidget);
    expect(find.text('MMIA  →  MMTO'), findsOneWidget);
    expect(find.text('10 ago 2026'), findsOneWidget);
    expect(find.text('12 ago 2026'), findsOneWidget);
    expect(find.text('2 pasajeros  •  2 tramos'), findsOneWidget);
  });
}
