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
            ctaLabel: 'Activar acceso comercial',
            onPrimaryAction: () {
              primaryTapped = true;
            },
            isPrimaryEnabled: true,
            isLoading: false,
          ),
        ),
      );

      expect(find.text('Configura tu pago'), findsOneWidget);
      expect(find.text('Acceso comercial premium'), findsAtLeastNWidgets(1));
      expect(find.text('ACTIVAR ACCESO COMERCIAL'), findsOneWidget);

      await tester.tap(find.text('ACTIVAR ACCESO COMERCIAL'));
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

      expect(find.text('Pago de vuelo'), findsOneWidget);
      expect(find.text('Toluca -> Monterrey'), findsAtLeastNWidgets(1));
      expect(find.text('IR A TUS VUELOS'), findsOneWidget);

      final tripsShortcut = find.text('Ir a Tus vuelos', skipOffstage: false);
      await tester.scrollUntilVisible(tripsShortcut, 200);

      await tester.tap(find.text('IR A TUS VUELOS'));
      await tester.pump();

      expect(primaryTapped, isTrue);
    });
  });
}
