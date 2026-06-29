import 'package:flutter/material.dart';

import 'client_payment_shared_widgets.dart';
import '../widgets/widgets_experiencia_cliente.dart';

class ClientFlightPaymentView extends StatelessWidget {
  const ClientFlightPaymentView({
    super.key,
    required this.showBackButton,
    required this.hasCustomBack,
    required this.onBack,
    required this.amount,
    required this.route,
    required this.passengerCount,
    required this.paymentBreakdown,
    required this.checkoutDescription,
    required this.checkoutStatus,
    required this.reservationPaymentConfirmed,
    required this.waitingForReservationCheckoutReturn,
    required this.submitting,
    required this.paymentMethod,
    required this.inlineMessage,
    required this.messageColor,
    required this.emailController,
    required this.cardPaymentPanel,
    required this.linkPaymentPanel,
    required this.onSelectCard,
    required this.onSelectLink,
    required this.showTripsShortcut,
    required this.onOpenTrips,
    required this.ctaLabel,
    required this.onPrimaryAction,
    required this.isPrimaryEnabled,
    required this.isLoading,
  });

  final bool showBackButton;
  final bool hasCustomBack;
  final VoidCallback onBack;
  final String amount;
  final String route;
  final String passengerCount;
  final List<PaymentBreakdownItem> paymentBreakdown;
  final String checkoutDescription;
  final String checkoutStatus;
  final bool reservationPaymentConfirmed;
  final bool waitingForReservationCheckoutReturn;
  final bool submitting;
  final String paymentMethod;
  final String inlineMessage;
  final Color messageColor;
  final TextEditingController emailController;
  final Widget cardPaymentPanel;
  final Widget linkPaymentPanel;
  final VoidCallback onSelectCard;
  final VoidCallback onSelectLink;
  final bool showTripsShortcut;
  final VoidCallback onOpenTrips;
  final String ctaLabel;
  final VoidCallback? onPrimaryAction;
  final bool isPrimaryEnabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      bottomNavigationBar: PaymentStickyFooter(
        totalLabel: amount,
        ctaLabel: ctaLabel,
        onPressed: isPrimaryEnabled ? onPrimaryAction : null,
        isLoading: isLoading,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 14, 0, 170),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  if (showBackButton || hasCustomBack)
                    PaymentRoundActionButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: onBack,
                    ),
                  if (showBackButton || hasCustomBack)
                    const SizedBox(width: 10),
                  const Spacer(),
                  const StatusBadge(
                    label: 'Checkout seguro',
                    color: Color(0xFF2D6A4F),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Pago de vuelo',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111111),
                  height: 0.98,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route,
                    style: const TextStyle(
                      color: Color(0xFF1E1E1E),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$passengerCount ${passengerCount == '1' ? 'pasajero' : 'pasajeros'}',
                    style: const TextStyle(
                      color: Color(0xFF625D55),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _PaymentTotalCard(
                amount: amount,
                route: route,
                paymentBreakdown: paymentBreakdown,
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _SecurePaymentBanner(),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ReservationSnapshotCard(
                route: route,
                passengerCount: passengerCount,
                amount: amount,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ExternalCheckoutCard(
                title: 'Checkout externo',
                description: checkoutDescription,
                status: checkoutStatus,
                isBusy: waitingForReservationCheckoutReturn || submitting,
                isConfirmed: reservationPaymentConfirmed,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _FlightPaymentMethodCard(
                paymentMethod: paymentMethod,
                onSelectCard: onSelectCard,
                onSelectLink: onSelectLink,
                cardPaymentPanel: cardPaymentPanel,
                linkPaymentPanel: linkPaymentPanel,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ContactCard(
                emailController: emailController,
                showTripsShortcut:
                    reservationPaymentConfirmed || showTripsShortcut,
                onOpenTrips: onOpenTrips,
                inlineMessage: inlineMessage,
                messageColor: messageColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentTotalCard extends StatelessWidget {
  const _PaymentTotalCard({
    required this.amount,
    required this.route,
    required this.paymentBreakdown,
  });

  final String amount;
  final String route;
  final List<PaymentBreakdownItem> paymentBreakdown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE5EAF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140E2238),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL',
            style: TextStyle(
              color: Color(0xFF7A6A53),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            route,
            style: const TextStyle(
              color: Color(0xFF3B3428),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (paymentBreakdown.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F3EB),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE6DDCE)),
              ),
              child: Column(
                children: [
                  for (var index = 0; index < paymentBreakdown.length; index++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: index == paymentBreakdown.length - 1 ? 0 : 8,
                      ),
                      child: PaymentRow(
                        label: paymentBreakdown[index].label,
                        value: paymentBreakdown[index].value,
                        emphasize: paymentBreakdown[index].total,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SecurePaymentBanner extends StatelessWidget {
  const _SecurePaymentBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF102438),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_rounded, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pago seguro',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tu reserva esta protegida mediante Stripe y validacion bancaria.',
                  style: TextStyle(
                    color: Color(0xFFD5E2EE),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservationSnapshotCard extends StatelessWidget {
  const _ReservationSnapshotCard({
    required this.route,
    required this.passengerCount,
    required this.amount,
  });

  final String route;
  final String passengerCount;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return GlassInfoCard(
      backgroundColor: const Color(0xFF102438),
      borderColor: const Color(0xFF29445A),
      shadowColor: const Color(0x1A102438),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RESERVA',
            style: TextStyle(
              color: Color(0xFFD6E1EA),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            route,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 14),
          PaymentRow(
            label: 'Pasajeros',
            value:
                '$passengerCount ${passengerCount == '1' ? 'pasajero' : 'pasajeros'}',
            onDark: true,
          ),
          const PaymentRow(
            label: 'Metodo',
            value: 'Stripe Checkout externo',
            onDark: true,
          ),
          PaymentRow(
            label: 'Total',
            value: amount,
            emphasize: true,
            onDark: true,
          ),
        ],
      ),
    );
  }
}

class _FlightPaymentMethodCard extends StatelessWidget {
  const _FlightPaymentMethodCard({
    required this.paymentMethod,
    required this.onSelectCard,
    required this.onSelectLink,
    required this.cardPaymentPanel,
    required this.linkPaymentPanel,
  });

  final String paymentMethod;
  final VoidCallback onSelectCard;
  final VoidCallback onSelectLink;
  final Widget cardPaymentPanel;
  final Widget linkPaymentPanel;

  @override
  Widget build(BuildContext context) {
    return GlassInfoCard(
      backgroundColor: const Color(0xFF102438),
      borderColor: const Color(0xFF29445A),
      shadowColor: const Color(0x1A102438),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Metodo de pago',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          CompactPaymentOption(
            label: 'Tarjeta Corporativa',
            subtitle: 'Visa / Mastercard / Amex',
            selected: paymentMethod == 'card',
            expanded: paymentMethod == 'card',
            onTap: onSelectCard,
            child: cardPaymentPanel,
          ),
          const SizedBox(height: 10),
          CompactPaymentOption(
            label: 'Link de Pago',
            subtitle: 'Abrimos Stripe Checkout en un enlace seguro',
            selected: paymentMethod == 'link',
            expanded: paymentMethod == 'link',
            onTap: onSelectLink,
            child: linkPaymentPanel,
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.emailController,
    required this.showTripsShortcut,
    required this.onOpenTrips,
    required this.inlineMessage,
    required this.messageColor,
  });

  final TextEditingController emailController;
  final bool showTripsShortcut;
  final VoidCallback onOpenTrips;
  final String inlineMessage;
  final Color messageColor;

  @override
  Widget build(BuildContext context) {
    return GlassInfoCard(
      backgroundColor: const Color(0xFF102438),
      borderColor: const Color(0xFF29445A),
      shadowColor: const Color(0x1A102438),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Datos de contacto',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          PaymentInputField(
            controller: emailController,
            label: 'Correo electronico',
            hint: 'cliente@empresa.com',
            keyboardType: TextInputType.emailAddress,
          ),
          if (showTripsShortcut) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onOpenTrips,
                icon: const Icon(Icons.flight_rounded, color: Colors.white),
                label: const Text(
                  'Ir a Tus vuelos',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ],
          if (inlineMessage.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              inlineMessage,
              style: TextStyle(
                color: messageColor,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
