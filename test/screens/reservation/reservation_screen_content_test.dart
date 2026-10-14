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

  // TEMPORAL: ACCESO COMERCIAL DESACTIVADO — 2026-10-14
  testWidgets(
    'allows quotes and hides expired-access CTA when access is expired',
    (tester) async {
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
              hasCommercialAccessData: true,
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
              onPickRouteTime: (_) {},
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

      expect(find.text('Acceso comercial vencido 29 julio 2026'), findsNothing);
      expect(find.text('Reactivar acceso comercial'), findsNothing);
      expect(find.text('Cotiza tu vuelo'), findsOneWidget);
      expect(find.text('Buscar vuelos'), findsOneWidget);
      expect(paymentOpened, isFalse);
    },
  );

  testWidgets('shows quote form and hides access card when access is active', (
    tester,
  ) async {
    final reservation = ReservationProvider();
    addTearDown(reservation.dispose);

    final activeState = resolveCommercialAccessState({
      'commercial_access': {
        'status': 'active',
        'expires_at': '2026-12-31',
        'has_paid_access': true,
        'available_actions': {
          'can_quote': true,
          'can_reserve': true,
          'can_renew': true,
        },
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReservationScreenContent(
            reservation: reservation,
            primaryRoute: reservation.routes.first,
            suggestedAirports: const [],
            dateFormat: DateFormat('dd/MM/yyyy'),
            tripType: 'Solo ida',
            departureTime: null,
            returnDate: null,
            returnTime: null,
            commercialState: activeState,
            hasCommercialAccessData: true,
            onOpenMembership: () {},
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
            onPickRouteTime: (_) {},
            onRemoveRoute: (_) {},
            onAddRoute: () {},
            onApplySuggestedDestination: (_) {},
            onPreview: () {},
          ),
        ),
      ),
    );

    expect(find.text('Cotiza tu vuelo'), findsOneWidget);
    expect(find.text('Buscar vuelos'), findsOneWidget);
    expect(find.textContaining('Acceso comercial vencido'), findsNothing);
  });

  testWidgets('multidestino starts with only tramo 1 and disables add route', (
    tester,
  ) async {
    final reservation = ReservationProvider();
    addTearDown(reservation.dispose);

    final activeState = resolveCommercialAccessState({
      'commercial_access': {
        'status': 'active',
        'expires_at': '2026-12-31',
        'has_paid_access': true,
        'available_actions': {
          'can_quote': true,
          'can_reserve': true,
          'can_renew': true,
        },
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReservationScreenContent(
            reservation: reservation,
            primaryRoute: reservation.routes.first,
            suggestedAirports: const [],
            dateFormat: DateFormat('dd/MM/yyyy'),
            tripType: 'Multidestino',
            departureTime: null,
            returnDate: null,
            returnTime: null,
            commercialState: activeState,
            hasCommercialAccessData: true,
            onOpenMembership: () {},
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
            onPickRouteTime: (_) {},
            onRemoveRoute: (_) {},
            onAddRoute: () {},
            onApplySuggestedDestination: (_) {},
            onPreview: () {},
          ),
        ),
      ),
    );

    expect(reservation.routes, hasLength(1));
    expect(find.text('TRAMO 1'), findsOneWidget);
    expect(find.text('Tramo 2'), findsNothing);

    final addButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '+ Agregar otro destino'),
    );
    expect(addButton.onPressed, isNull);
  });

  testWidgets('allows quote form for pending inactive and blocked access', (
    tester,
  ) async {
    for (final status in ['pending', 'inactive', 'blocked']) {
      final reservation = ReservationProvider();
      addTearDown(reservation.dispose);
      final state = resolveCommercialAccessState({
        'commercial_access': {
          'status': status,
          'has_paid_access': false,
          'available_actions': {
            'can_quote': false,
            'can_reserve': false,
            'can_renew': true,
          },
        },
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReservationScreenContent(
              reservation: reservation,
              primaryRoute: reservation.routes.first,
              suggestedAirports: const [],
              dateFormat: DateFormat('dd/MM/yyyy'),
              tripType: 'Solo ida',
              departureTime: null,
              returnDate: null,
              returnTime: null,
              commercialState: state,
              hasCommercialAccessData: true,
              onOpenMembership: () {},
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
              onPickRouteTime: (_) {},
              onRemoveRoute: (_) {},
              onAddRoute: () {},
              onApplySuggestedDestination: (_) {},
              onPreview: () {},
            ),
          ),
        ),
      );

      expect(find.text('Cotiza tu vuelo'), findsOneWidget);
      expect(find.textContaining('Acceso comercial vencido'), findsNothing);
      expect(find.text('Reactivar acceso comercial'), findsNothing);
    }
  });

  testWidgets('shows quote form while commercial access is not checked', (
    tester,
  ) async {
    final reservation = ReservationProvider();
    addTearDown(reservation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReservationScreenContent(
            reservation: reservation,
            primaryRoute: reservation.routes.first,
            suggestedAirports: const [],
            dateFormat: DateFormat('dd/MM/yyyy'),
            tripType: 'Solo ida',
            departureTime: null,
            returnDate: null,
            returnTime: null,
            commercialState: resolveCommercialAccessState(null),
            hasCommercialAccessData: false,
            onOpenMembership: () {},
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
            onPickRouteTime: (_) {},
            onRemoveRoute: (_) {},
            onAddRoute: () {},
            onApplySuggestedDestination: (_) {},
            onPreview: () {},
          ),
        ),
      ),
    );

    expect(find.text('Cotiza tu vuelo'), findsOneWidget);
    expect(find.text('No pudimos comprobar tu acceso'), findsNothing);
  });
}
