import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:red_sky/providers/proveedor_reservaciones.dart';
import 'package:red_sky/screens/reservation/pantalla_vista_previa_cotizacion.dart';

void main() {
  testWidgets(
    'uses backend pricing total_amount in quote preview instead of stale final_price',
    (tester) async {
      final reservation = ReservationProvider();
      addTearDown(reservation.dispose);

      reservation.selectedQuoteMatch = {
        'id': 'match-preview',
        'match_id': 'match-preview',
        'aircraft_name': 'GULFSTREAM G450',
        'final_price': 'USD 13,535',
        'pricing': {'total_amount': 42960},
        'pricing_breakdown': {'final_billable_hours': 4.0},
      };

      await tester.pumpWidget(
        ChangeNotifierProvider<ReservationProvider>.value(
          value: reservation,
          child: const MaterialApp(home: QuotePreviewScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('USD42,960'), findsOneWidget);
      expect(find.text('USD 13,535'), findsNothing);
    },
  );

  testWidgets(
    'renders Learjet 45 preview with the same backend normalized time as the web example',
    (tester) async {
      final reservation = ReservationProvider();
      addTearDown(reservation.dispose);

      reservation.selectedQuoteMatch = {
        'id': 'match-preview-learjet-45',
        'match_id': 'match-preview-learjet-45',
        'aircraft_name': 'LEARJET 45',
        'time': '4 h 50 min',
        'trip_time': '4 h 50 min',
        'card_time': '4 h 50 min',
        'pricing': {'total_amount': 18874},
        'pricing_breakdown': {'final_billable_hours': 4.83},
      };

      await tester.pumpWidget(
        ChangeNotifierProvider<ReservationProvider>.value(
          value: reservation,
          child: const MaterialApp(home: QuotePreviewScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('4 h 50 min'), findsOneWidget);
      expect(find.text('Horas cobrables backend: 4 h 50 min'), findsOneWidget);
      expect(find.text('1 h 00 min'), findsNothing);
      expect(find.text('USD18,874'), findsOneWidget);
    },
  );

  testWidgets(
    'reuses the official display route hours when legacy trip labels are stale',
    (tester) async {
      final reservation = ReservationProvider();
      addTearDown(reservation.dispose);

      reservation.selectedQuoteMatch = {
        'id': 'match-preview-display-route-hours',
        'match_id': 'match-preview-display-route-hours',
        'aircraft_name': 'LEARJET 45',
        'time': '1 h 50 min',
        'trip_time': '4 h 50 min',
        'card_time': '4 h 50 min',
        'pricing': {'total_amount': 18874, 'display_route_hours': 1.83},
        'pricing_breakdown': {
          'display_route_hours': 1.83,
          'final_billable_hours': 4.83,
        },
      };

      await tester.pumpWidget(
        ChangeNotifierProvider<ReservationProvider>.value(
          value: reservation,
          child: const MaterialApp(home: QuotePreviewScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('1 h 50 min'), findsWidgets);
      expect(find.text('4 h 50 min'), findsNothing);
    },
  );
}
