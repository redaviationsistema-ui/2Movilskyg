import 'package:flutter/material.dart';

import 'client_payment_shared_widgets.dart';

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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFF071321),
      bottomNavigationBar: _AccessCheckoutFooter(
        amount: amount,
        ctaLabel: commercialAccessActive ? ctaLabel : 'Continuar al pago',
        onPressed: isPrimaryEnabled ? onPrimaryAction : null,
        isLoading: isLoading,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: _AccessPaymentHeader(
                showBackButton: showBackButton || hasCustomBack,
                onBack: onBack,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 28),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
                  duration:
                      reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * 10),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AccessPaymentIntro(
                        headline: headline,
                        subheadline: subheadline,
                        statusCaption: statusCaption,
                      ),
                      const SizedBox(height: 24),
                      _AccessTotalCard(
                        amount: amount,
                        paymentBreakdown: paymentBreakdown,
                      ),
                      if (commercialAccessActive) ...[
                        const SizedBox(height: 14),
                        ExternalCheckoutCard(
                          title: 'Acceso comercial activo',
                          description: checkoutDescription,
                          status: checkoutStatus,
                          isConfirmed: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessPaymentHeader extends StatelessWidget {
  const _AccessPaymentHeader({
    required this.showBackButton,
    required this.onBack,
  });

  final bool showBackButton;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          if (showBackButton)
            InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF132438),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF344459)),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFFD6B477),
                  size: 22,
                ),
              ),
            ),
          const Spacer(),
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF132438),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF344459)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: Color(0xFF3FC18A),
                  size: 16,
                ),
                SizedBox(width: 7),
                Text(
                  'Pago seguro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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

class _AccessPaymentIntro extends StatelessWidget {
  const _AccessPaymentIntro({
    required this.headline,
    required this.subheadline,
    required this.statusCaption,
  });

  final String headline;
  final String subheadline;
  final String statusCaption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACCESO COMERCIAL',
          style: TextStyle(
            color: Color(0xFFD6B477),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _withTerminalPeriod(headline),
          style: const TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.04,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _withTerminalPeriod(subheadline),
          style: const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 16,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          statusCaption,
          style: const TextStyle(
            color: Color(0xFFB7C4D3),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.38,
          ),
        ),
      ],
    );
  }

  String _withTerminalPeriod(String value) {
    final text = value.trim();
    if (text.isEmpty || text.endsWith('.') || text.endsWith('!')) return text;
    return '$text.';
  }
}

class _AccessCheckoutFooter extends StatelessWidget {
  const _AccessCheckoutFooter({
    required this.amount,
    required this.ctaLabel,
    required this.onPressed,
    required this.isLoading,
  });

  final String amount;
  final String ctaLabel;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        decoration: const BoxDecoration(
          color: Color(0xFF071321),
          border: Border(top: BorderSide(color: Color(0xFF344459))),
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 22,
              offset: Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pago procesado mediante Stripe.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFB7C4D3),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    amount,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFFD6B477),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: const Color(0xFFD6B477),
                  foregroundColor: const Color(0xFF071321),
                  disabledBackgroundColor: const Color(0xFF344459),
                  disabledForegroundColor: const Color(0xFFB7C4D3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child:
                      isLoading
                          ? const SizedBox(
                            key: ValueKey('loading'),
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF071321),
                            ),
                          )
                          : Row(
                            key: const ValueKey('label'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_outline_rounded, size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  ctaLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
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
        color: const Color(0xFF132438),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF344459)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL A PAGAR',
            style: TextStyle(
              color: Color(0xFFD6B477),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                height: 0.95,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Reactivacion de acceso comercial',
            style: TextStyle(
              color: Color(0xFFB7C4D3),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (paymentBreakdown.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Divider(height: 1, color: Color(0xFF344459)),
            const SizedBox(height: 6),
            for (var index = 0; index < paymentBreakdown.length; index++)
              _AccessBreakdownRow(
                item: paymentBreakdown[index],
                isLast: index == paymentBreakdown.length - 1,
              ),
          ],
        ],
      ),
    );
  }
}

class _AccessBreakdownRow extends StatelessWidget {
  const _AccessBreakdownRow({required this.item, required this.isLast});

  final PaymentBreakdownItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final labelColor =
        item.total ? const Color(0xFFD6B477) : const Color(0xFFB7C4D3);
    final valueColor = item.total ? const Color(0xFFD6B477) : Colors.white;

    return Column(
      children: [
        if (item.total) const Divider(height: 14, color: Color(0xFF344459)),
        Padding(
          padding: EdgeInsets.symmetric(vertical: item.total ? 5 : 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 13,
                    fontWeight: item.total ? FontWeight.w900 : FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: item.total ? 15 : 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast && !item.total)
          const Divider(height: 1, color: Color(0x22344459)),
      ],
    );
  }
}
