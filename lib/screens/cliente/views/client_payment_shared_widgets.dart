import 'package:flutter/material.dart';

import '../tema_cliente.dart';
import '../widgets/widgets_experiencia_cliente.dart';

class PaymentBreakdownItem {
  const PaymentBreakdownItem({
    required this.label,
    required this.value,
    this.total = false,
  });

  final String label;
  final String value;
  final bool total;
}

class PaymentInputField extends StatelessWidget {
  const PaymentInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      cursorColor: ClientThemeColors.brandNavy,
      style: const TextStyle(
        color: Color(0xFF102438),
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(
          color: Color(0xFF6C7680),
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF102438),
          fontWeight: FontWeight.w700,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF9AA5AF),
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class PaymentRoundActionButton extends StatelessWidget {
  const PaymentRoundActionButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE4EAF0)),
        ),
        child: Icon(icon, color: ClientThemeColors.brandNavy, size: 20),
      ),
    );
  }
}

class CardBrandMark extends StatelessWidget {
  const CardBrandMark({super.key, required this.brand});

  final String brand;

  @override
  Widget build(BuildContext context) {
    final normalized = brand.trim().toLowerCase();
    if (normalized.contains('master')) {
      return Container(
        width: 40,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: const [
            Positioned(
              left: 9,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: Color(0xFFEB001B),
              ),
            ),
            Positioned(
              right: 9,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: Color(0xFFF79E1B),
              ),
            ),
          ],
        ),
      );
    }
    if (normalized.contains('visa')) {
      return const CardBrandTextBadge(label: 'VISA');
    }
    if (normalized.contains('amex')) {
      return const CardBrandTextBadge(label: 'AMEX');
    }
    return Container(
      width: 40,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.credit_card_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}

class CardBrandTextBadge extends StatelessWidget {
  const CardBrandTextBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 40, minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class CardMetaItem extends StatelessWidget {
  const CardMetaItem({
    super.key,
    required this.label,
    required this.value,
    required this.alignEnd,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF8FA4B8),
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class PaymentRow extends StatelessWidget {
  const PaymentRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.onDark = false,
  });

  final String label;
  final String value;
  final bool emphasize;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color:
                    onDark
                        ? Colors.white70
                        : emphasize
                        ? const Color(0xFF111111)
                        : const Color(0xFF625D55),
                fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: onDark ? Colors.white : const Color(0xFF111111),
                fontWeight: emphasize ? FontWeight.w900 : FontWeight.w800,
                fontSize: emphasize ? 18 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CompactPaymentOption extends StatelessWidget {
  const CompactPaymentOption({
    super.key,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.expanded,
    required this.onTap,
    required this.child,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final bool expanded;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF7FAFD) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              selected ? ClientThemeColors.brandNavy : ClientThemeColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color:
                        selected
                            ? ClientThemeColors.brandNavy
                            : const Color(0xFF9DA8B3),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFF625D55),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF625D55),
                  ),
                ],
              ),
              if (expanded) child,
            ],
          ),
        ),
      ),
    );
  }
}

class ExternalCheckoutCard extends StatelessWidget {
  const ExternalCheckoutCard({
    super.key,
    required this.title,
    required this.description,
    required this.status,
    this.isBusy = false,
    this.isConfirmed = false,
  });

  final String title;
  final String description;
  final String status;
  final bool isBusy;
  final bool isConfirmed;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        isConfirmed
            ? const Color(0xFF9BE7B0)
            : isBusy
            ? const Color(0xFFE0B86E)
            : const Color(0xFFF5B0A8);
    final statusIcon =
        isConfirmed
            ? Icons.check_circle_rounded
            : isBusy
            ? Icons.sync_rounded
            : Icons.open_in_new_rounded;

    return GlassInfoCard(
      backgroundColor: ClientThemeColors.brandNavy,
      borderColor: const Color(0xFF29445A),
      shadowColor: const Color(0x1A102438),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child:
                    isBusy
                        ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Icon(statusIcon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 13,
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
            description,
            style: const TextStyle(
              color: Color(0xFFD5E2EE),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.42,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No capturamos ni guardamos tu tarjeta dentro de la app.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
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

class PaymentStickyFooter extends StatelessWidget {
  const PaymentStickyFooter({
    super.key,
    required this.totalLabel,
    required this.ctaLabel,
    required this.onPressed,
    required this.isLoading,
  });

  final String totalLabel;
  final String ctaLabel;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5EAF0))),
          boxShadow: [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 22,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total',
              style: TextStyle(
                color: Color(0xFF7A6A53),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  totalLabel,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: ClientThemeColors.brandNavy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD4DAE1),
                  disabledForegroundColor: const Color(0xFF5E6A77),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child:
                    isLoading
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Text(
                          ctaLabel.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
