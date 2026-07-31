import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/screens/cliente/views/client_access_payment_view.dart';
import 'package:red_sky/screens/cliente/views/client_flight_payment_view.dart';
import 'package:red_sky/screens/cliente/views/client_payment_shared_widgets.dart';

void main() {
  group('Client payment views', () {
    testWidgets('renders access payment flow in its own view', (tester) async {
      final emailController = TextEditingController(text: 'red@gmail.com');
      addTearDown(emailController.dispose);

      var primaryTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ClientAccessPaymentView(
            showBackButton: true,
            hasCustomBack: false,
            onBack: () {},
            commercialAccessActive: false,
            headline: 'Reactiva tu acceso comercial',
            subheadline: 'Tu acceso vencio el 29 julio 2026',
            statusCaption:
                'Completa el pago mediante Stripe para volver a cotizar y reservar vuelos.',
            amount: 'USD \$299.00',
            paymentBreakdown: const [
              PaymentBreakdownItem(
                label: 'Plan mensual',
                value: 'USD \$299.00',
              ),
            ],
            checkoutDescription: 'Checkout listo para acceso comercial.',
            checkoutStatus: 'Listo para pagar',
            paymentMethodSummaryLabel: 'Stripe Checkout externo',
            showCommercialCardPaymentOption: true,
            paymentMethod: 'link',
            cardPaymentPanel: const SizedBox.shrink(),
            linkPaymentPanel: const SizedBox.shrink(),
            onSelectCard: () {},
            onSelectLink: () {},
            inlineMessage: '',
            messageColor: Colors.green,
            emailController: emailController,
            ctaLabel: 'Continuar con Stripe',
            onPrimaryAction: () {
              primaryTapped = true;
            },
            isPrimaryEnabled: true,
            isLoading: false,
          ),
        ),
      );

      expect(find.text('Reactiva tu acceso comercial'), findsOneWidget);
      expect(find.text('Tu acceso vencio el 29 julio 2026'), findsOneWidget);
      expect(
        find.text(
          'Completa el pago mediante Stripe para volver a cotizar y reservar vuelos.',
        ),
        findsOneWidget,
      );
      expect(find.text('CONTINUAR CON STRIPE'), findsOneWidget);

      await tester.tap(find.text('CONTINUAR CON STRIPE'));
      await tester.pump();

      expect(primaryTapped, isTrue);
    });

    testWidgets('renders flight payment flow in its own view', (tester) async {
      final emailController = TextEditingController(text: 'red@gmail.com');
      addTearDown(emailController.dispose);

      var primaryTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ClientFlightPaymentView(
            showBackButton: true,
            hasCustomBack: false,
            onBack: () {},
            amount: 'USD \$15990.00',
            route: 'Toluca -> Monterrey',
            passengerCount: '1',
            aircraftLabel: 'Learjet 45',
            departureLabel: '30/07/2026 10:00',
            paymentBreakdown: const [
              PaymentBreakdownItem(
                label: 'Total reserva',
                value: 'USD \$15990.00',
                total: true,
              ),
            ],
            checkoutDescription:
                'El cobro se completa fuera de la app en Stripe.',
            checkoutStatus: 'Listo para abrir enlace seguro',
            reservationPaymentConfirmed: true,
            waitingForReservationCheckoutReturn: false,
            submitting: false,
            paymentMethod: 'link',
            inlineMessage: '',
            messageColor: Colors.green,
            emailController: emailController,
            cardPaymentPanel: const SizedBox.shrink(),
            linkPaymentPanel: const SizedBox.shrink(),
            onSelectCard: () {},
            onSelectLink: () {},
            showTripsShortcut: true,
            onOpenTrips: () {},
            ctaLabel: 'Ir a Tus vuelos',
            onPrimaryAction: () {
              primaryTapped = true;
            },
            isPrimaryEnabled: true,
            isLoading: false,
          ),
        ),
      );

      expect(find.text('Pago seguro'), findsOneWidget);
      expect(find.text('Toluca → Monterrey'), findsAtLeastNWidgets(1));
      final tripsShortcut = find.text('Ir a Tus vuelos', skipOffstage: false);
      await tester.scrollUntilVisible(tripsShortcut, 200);

      await tester.tap(tripsShortcut);
      await tester.pump();

      expect(primaryTapped, isTrue);
    });
  });
}
