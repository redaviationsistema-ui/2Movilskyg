import 'dart:ui';

import 'package:flutter/material.dart';

import 'client_payment_shared_widgets.dart';

class ClientFlightPaymentView extends StatelessWidget {
  const ClientFlightPaymentView({
    super.key,
    required this.showBackButton,
    required this.hasCustomBack,
    required this.onBack,
    required this.amount,
    required this.route,
    required this.passengerCount,
    required this.aircraftLabel,
    required this.departureLabel,
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
  final String aircraftLabel;
  final String departureLabel;
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

  static const _background = Color(0xFF07111D);

  @override
  Widget build(BuildContext context) {
    final passengerLabel =
        '$passengerCount ${passengerCount == '1' ? 'pasajero' : 'pasajeros'}';

    return Scaffold(
      backgroundColor: _background,
      bottomNavigationBar: _PremiumPaymentFooter(
        amount: amount,
        ctaLabel: ctaLabel,
        enabled: isPrimaryEnabled,
        loading: isLoading,
        onPressed: onPrimaryAction,
      ),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _PaymentHeader(
                  showBack: showBackButton || hasCustomBack,
                  onBack: onBack,
                  route: route,
                  passengerLabel: passengerLabel,
                  departureLabel: departureLabel,
                  confirmed: reservationPaymentConfirmed,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _PremiumPaymentHero(
                    amount: amount,
                    route: route,
                    aircraftLabel: aircraftLabel,
                    passengerLabel: passengerLabel,
                  ),
                  const SizedBox(height: 20),
                  _PaymentBreakdownList(items: paymentBreakdown, total: amount),
                  const SizedBox(height: 20),
                  _ReservationSummary(
                    passengerLabel: passengerLabel,
                    aircraftLabel: aircraftLabel,
                  ),
                  const SizedBox(height: 20),
                  _StripeSecurityCard(
                    status: checkoutStatus,
                    confirmed: reservationPaymentConfirmed,
                    busy: waitingForReservationCheckoutReturn || submitting,
                  ),
                  const SizedBox(height: 16),
                  _ContactInformationRow(
                    controller: emailController,
                    showTripsShortcut:
                        reservationPaymentConfirmed || showTripsShortcut,
                    onOpenTrips: onOpenTrips,
                  ),
                  const SizedBox(height: 16),
                  const _StripeMethodRow(),
                  const SizedBox(height: 16),
                  const _PaymentBenefits(),
                  if (inlineMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _PaymentInlineMessage(
                      message: inlineMessage,
                      color: messageColor,
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentHeader extends StatelessWidget {
  const _PaymentHeader({
    required this.showBack,
    required this.onBack,
    required this.route,
    required this.passengerLabel,
    required this.departureLabel,
    required this.confirmed,
  });

  final bool showBack;
  final VoidCallback onBack;
  final String route;
  final String passengerLabel;
  final String departureLabel;
  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (showBack) ...[
              InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF101C2D),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .09),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            const Expanded(
              child: Text(
                'Pago seguro',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF30D158).withValues(alpha: .09),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFF30D158).withValues(alpha: .34),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    confirmed
                        ? Icons.check_circle_rounded
                        : Icons.verified_user_outlined,
                    color: const Color(0xFF30D158),
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    confirmed ? 'Pago verificado' : 'Stripe Verified',
                    style: const TextStyle(
                      color: Color(0xFF30D158),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          route.replaceAll('->', '→'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFD8B15D),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Flexible(
              child: Text(
                passengerLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .62),
                  fontSize: 11.5,
                ),
              ),
            ),
            Container(
              width: 3,
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .4),
              ),
            ),
            Flexible(
              flex: 2,
              child: Text(
                departureLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .62),
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PremiumPaymentHero extends StatelessWidget {
  const _PremiumPaymentHero({
    required this.amount,
    required this.route,
    required this.aircraftLabel,
    required this.passengerLabel,
  });

  final String amount;
  final String route;
  final String aircraftLabel;
  final String passengerLabel;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .97, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (_, value, child) => Transform.scale(scale: value, child: child),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFF101C2D),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: .09)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 160,
              child: Image.asset(
                'assets/login/image.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF101C2D),
                    Color(0xF0101C2D),
                    Color(0x70101C2D),
                  ],
                  stops: [0, .58, 1],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL A PAGAR',
                    style: TextStyle(
                      color: Color(0xFFD8B15D),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    width: 265,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        amount,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    route.replaceAll('->', '→'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: 230,
                    child: Text(
                      '$aircraftLabel  •  $passengerLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .65),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentBreakdownList extends StatelessWidget {
  const _PaymentBreakdownList({required this.items, required this.total});

  final List<PaymentBreakdownItem> items;
  final String total;

  @override
  Widget build(BuildContext context) {
    final details = items.where((item) => !item.total).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Desglose',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 15),
        if (details.isEmpty)
          _BreakdownRow(label: 'Costo del vuelo', value: total)
        else
          for (final item in details)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BreakdownRow(label: item.label, value: item.value),
            ),
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: Colors.white.withValues(alpha: .09),
        ),
        const SizedBox(height: 12),
        _BreakdownRow(label: 'TOTAL', value: total, emphasized: true),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color:
                  emphasized
                      ? Colors.white
                      : Colors.white.withValues(alpha: .66),
              fontSize: emphasized ? 14 : 13,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: emphasized ? const Color(0xFFD8B15D) : Colors.white,
            fontSize: emphasized ? 18 : 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ReservationSummary extends StatelessWidget {
  const _ReservationSummary({
    required this.passengerLabel,
    required this.aircraftLabel,
  });

  final String passengerLabel;
  final String aircraftLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF101C2D),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryColumn(
              icon: Icons.person_outline_rounded,
              label: passengerLabel,
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _SummaryColumn(
              icon: Icons.flight_rounded,
              label: aircraftLabel,
            ),
          ),
          _VerticalDivider(),
          const Expanded(
            child: _SummaryColumn(
              icon: Icons.credit_card_rounded,
              label: 'Stripe Checkout',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFD8B15D), size: 22),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      color: Colors.white.withValues(alpha: .08),
    );
  }
}

class _StripeSecurityCard extends StatelessWidget {
  const _StripeSecurityCard({
    required this.status,
    required this.confirmed,
    required this.busy,
  });

  final String status;
  final bool confirmed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101C2D),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF30D158).withValues(alpha: .18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF30D158).withValues(alpha: .1),
            ),
            child:
                busy
                    ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF30D158),
                      ),
                    )
                    : Icon(
                      confirmed
                          ? Icons.check_circle_rounded
                          : Icons.shield_outlined,
                      color: const Color(0xFF30D158),
                      size: 25,
                    ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pago seguro con Stripe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Nunca almacenamos tu tarjeta.\n'
                  'El cobro se realiza directamente por Stripe.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .62),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF30D158),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
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

class _ContactInformationRow extends StatelessWidget {
  const _ContactInformationRow({
    required this.controller,
    required this.showTripsShortcut,
    required this.onOpenTrips,
  });

  final TextEditingController controller;
  final bool showTripsShortcut;
  final VoidCallback onOpenTrips;

  Future<void> _editEmail(BuildContext context) async {
    final temporary = TextEditingController(text: controller.text);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
              decoration: const BoxDecoration(
                color: Color(0xFF101C2D),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Correo de contacto',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: temporary,
                      autofocus: true,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF07111D),
                        hintText: 'correo@empresa.com',
                        hintStyle: const TextStyle(color: Colors.white38),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFD8B15D),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          controller.text = temporary.text.trim();
                          Navigator.pop(sheetContext);
                        },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: const Color(0xFFD8B15D),
                          foregroundColor: const Color(0xFF07111D),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Guardar',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
    temporary.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF101C2D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.mail_outline_rounded,
            color: Color(0xFFD8B15D),
            size: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Correo',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .48),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  controller.text.trim().isEmpty
                      ? 'Correo por confirmar'
                      : controller.text.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (showTripsShortcut)
            TextButton(onPressed: onOpenTrips, child: const Text('Mis vuelos'))
          else
            TextButton(
              onPressed: () => _editEmail(context),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD8B15D),
              ),
              child: const Text(
                'Editar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

class _StripeMethodRow extends StatelessWidget {
  const _StripeMethodRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 17),
      decoration: BoxDecoration(
        color: const Color(0xFF101C2D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: const Row(
        children: [
          Icon(Icons.credit_card_rounded, color: Color(0xFFD8B15D), size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Stripe Checkout',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(Icons.check_circle_rounded, color: Color(0xFF30D158), size: 18),
          SizedBox(width: 6),
          Text(
            'Recomendado',
            style: TextStyle(
              color: Color(0xFF30D158),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentBenefits extends StatelessWidget {
  const _PaymentBenefits();

  @override
  Widget build(BuildContext context) {
    const benefits = [
      'Pago cifrado',
      'PCI DSS',
      'Validación bancaria',
      'Regreso automático',
    ];

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF101C2D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        children:
            benefits
                .map(
                  (benefit) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        color: Color(0xFF30D158),
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        benefit,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _PaymentInlineMessage extends StatelessWidget {
  const _PaymentInlineMessage({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: color,
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PremiumPaymentFooter extends StatelessWidget {
  const _PremiumPaymentFooter({
    required this.amount,
    required this.ctaLabel,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final String amount;
  final String ctaLabel;
  final bool enabled;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 11, 18, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1523).withValues(alpha: .94),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: .08)),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 112,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .48),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          amount,
                          style: const TextStyle(
                            color: Color(0xFFD8B15D),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: enabled && !loading ? onPressed : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      height: 56,
                      decoration: BoxDecoration(
                        gradient:
                            enabled
                                ? const LinearGradient(
                                  colors: [
                                    Color(0xFFF0D184),
                                    Color(0xFFD8AA45),
                                  ],
                                )
                                : null,
                        color: enabled ? null : const Color(0xFF273242),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow:
                            enabled
                                ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFD8B15D,
                                    ).withValues(alpha: .16),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ]
                                : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (loading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF07111D),
                              ),
                            )
                          else
                            Icon(
                              Icons.lock_rounded,
                              color:
                                  enabled
                                      ? const Color(0xFF07111D)
                                      : Colors.white38,
                              size: 19,
                            ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              ctaLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color:
                                    enabled
                                        ? const Color(0xFF07111D)
                                        : Colors.white38,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
