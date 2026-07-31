import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:red_sky/core/acceso_comercial_cliente.dart';
import 'package:red_sky/models/modelo_ruta.dart';
import 'package:red_sky/providers/proveedor_reservaciones.dart';
import 'package:red_sky/screens/reservation/widgets/contenido_pantalla_reservacion.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
  });

  testWidgets('shows reactivation CTA when commercial access is expired', (
    tester,
  ) async {
    final reservation = ReservationProvider();
    addTearDown(reservation.dispose);

    final route = reservation.routes.first;
    route.fromCity = 'Toluca';
    route.toCity = 'Monterrey';
    route.startDate = DateTime(2026, 8, 2);

    final expiredState = resolveCommercialAccessState({
      'commercial_access': {
        'status': 'expired',
        'expires_at': '2026-07-29',
        'has_paid_access': false,
      },
    });

    var paymentOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReservationScreenContent(
            reservation: reservation,
            primaryRoute: RouteModel(startDate: route.startDate),
            suggestedAirports: const [],
            dateFormat: DateFormat('dd/MM/yyyy'),
            tripType: 'Solo ida',
            departureTime: null,
            returnDate: null,
            returnTime: null,
            commercialState: expiredState,
            onTodayTrip: () {},
            onRoundTrip: () {},
            onMultiCity: () {},
            onOpenMembership: () {
              paymentOpened = true;
            },
            onTripTypeChanged: (_) {},
            onPickOrigin: () {},
            onPickDestination: () {},
            onPickPrimaryDate: () {},
            onPickDepartureTime: () {},
            onPickReturnDate: () {},
            onPickReturnTime: () {},
            onPassengerChanged: (_) {},
            onPickRouteOrigin: (_) {},
            onPickRouteDestination: (_) {},
            onPickRouteDate: (_) {},
            onRemoveRoute: (_) {},
            onAddRoute: () {},
            onApplySuggestedDestination: (_) {},
            onPreview: () {
              paymentOpened = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Acceso comercial vencido 29 julio 2026'), findsOneWidget);
    expect(find.text('Reactivar acceso comercial'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('Reactivar acceso comercial').first);
    await tester.pump();

    expect(paymentOpened, isTrue);
  });
}
