import 'package:flutter/material.dart';

import 'client_payment_shared_widgets.dart';
import '../widgets/widgets_experiencia_cliente.dart';

class ClientAccessPaymentView extends StatelessWidget {
  const ClientAccessPaymentView({
    super.key,
    required this.showBackButton,
    required this.hasCustomBack,
    required this.onBack,
    required this.commercialAccessActive,
    required this.headline,
    required this.subheadline,
    required this.statusCaption,
    required this.amount,
    required this.paymentBreakdown,
    required this.checkoutDescription,
    required this.checkoutStatus,
    required this.paymentMethodSummaryLabel,
    required this.showCommercialCardPaymentOption,
    required this.paymentMethod,
    required this.cardPaymentPanel,
    required this.linkPaymentPanel,
    required this.onSelectCard,
    required this.onSelectLink,
    required this.inlineMessage,
    required this.messageColor,
    required this.emailController,
    required this.ctaLabel,
    required this.onPrimaryAction,
    required this.isPrimaryEnabled,
    required this.isLoading,
  });

  final bool showBackButton;
  final bool hasCustomBack;
  final VoidCallback onBack;
  final bool commercialAccessActive;
  final String headline;
  final String subheadline;
  final String statusCaption;
  final String amount;
  final List<PaymentBreakdownItem> paymentBreakdown;
  final String checkoutDescription;
  final String checkoutStatus;
  final String paymentMethodSummaryLabel;
  final bool showCommercialCardPaymentOption;
  final String paymentMethod;
  final Widget cardPaymentPanel;
  final Widget linkPaymentPanel;
  final VoidCallback onSelectCard;
  final VoidCallback onSelectLink;
  final String inlineMessage;
  final Color messageColor;
  final TextEditingController emailController;
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                headline,
                style: const TextStyle(
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
                    subheadline,
                    style: const TextStyle(
                      color: Color(0xFF1E1E1E),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusCaption,
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
              child: _AccessTotalCard(
                amount: amount,
                paymentBreakdown: paymentBreakdown,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _AccessSnapshotCard(
                amount: amount,
                paymentMethodSummaryLabel: paymentMethodSummaryLabel,
              ),
            ),
            const SizedBox(height: 12),
            if (!commercialAccessActive)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _AccessPaymentMethodCard(
                  showCommercialCardPaymentOption:
                      showCommercialCardPaymentOption,
                  paymentMethod: paymentMethod,
                  cardPaymentPanel: cardPaymentPanel,
                  linkPaymentPanel: linkPaymentPanel,
                  onSelectCard: onSelectCard,
                  onSelectLink: onSelectLink,
                ),
              ),
            if (commercialAccessActive)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ExternalCheckoutCard(
                  title: 'Acceso comercial activo',
                  description: checkoutDescription,
                  status: checkoutStatus,
                  isConfirmed: true,
                ),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _AccessContactCard(
                emailController: emailController,
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

class _AccessTotalCard extends StatelessWidget {
  const _AccessTotalCard({
    required this.amount,
    required this.paymentBreakdown,
  });

  final String amount;
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
          const Text(
            'Acceso comercial',
            style: TextStyle(
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

class _AccessSnapshotCard extends StatelessWidget {
  const _AccessSnapshotCard({
    required this.amount,
    required this.paymentMethodSummaryLabel,
  });

  final String amount;
  final String paymentMethodSummaryLabel;

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
          const Text(
            'Acceso comercial premium',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 14),
          const PaymentRow(
            label: 'Pasajeros',
            value: 'Membresia mensual',
            onDark: true,
          ),
          PaymentRow(
            label: 'Metodo',
            value: paymentMethodSummaryLabel,
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

class _AccessPaymentMethodCard extends StatelessWidget {
  const _AccessPaymentMethodCard({
    required this.showCommercialCardPaymentOption,
    required this.paymentMethod,
    required this.cardPaymentPanel,
    required this.linkPaymentPanel,
    required this.onSelectCard,
    required this.onSelectLink,
  });

  final bool showCommercialCardPaymentOption;
  final String paymentMethod;
  final Widget cardPaymentPanel;
  final Widget linkPaymentPanel;
  final VoidCallback onSelectCard;
  final VoidCallback onSelectLink;

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
            label: 'Agregar tarjeta con Stripe',
            subtitle: 'Captura tu tarjeta en la pagina segura de Stripe',
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

class _AccessContactCard extends StatelessWidget {
  const _AccessContactCard({
    required this.emailController,
    required this.inlineMessage,
    required this.messageColor,
  });

  final TextEditingController emailController;
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
