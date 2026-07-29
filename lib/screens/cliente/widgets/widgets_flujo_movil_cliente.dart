import 'package:flutter/material.dart';

import '../tema_cliente.dart';

class ClientMobileTopBar extends StatelessWidget {
  const ClientMobileTopBar({
    super.key,
    this.title = 'Sky Group',
    this.subtitle = 'Private aviation',
    this.onSignOut,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 56,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE6ECF2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              'assets/LOGOINTERNO.png',
              fit: BoxFit.contain,
              color: isDark ? palette.primary : null,
              colorBlendMode: isDark ? BlendMode.srcIn : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onSignOut,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE6ECF2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.logout_rounded,
                  color: palette.primary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ClientMobileScreenShell extends StatelessWidget {
  const ClientMobileScreenShell({
    super.key,
    required this.child,
    this.welcomeTitle = 'Sky Group',
    this.welcomeSubtitle = 'Private aviation',
    this.onSignOut,
  });

  final Widget child;
  final String welcomeTitle;
  final String welcomeSubtitle;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Material(
      color: palette.background,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              decoration: BoxDecoration(
                color: palette.background,
                border: Border(bottom: BorderSide(color: palette.border)),
              ),
              child: ClientMobileTopBar(
                title: welcomeTitle,
                subtitle: welcomeSubtitle,
                onSignOut: onSignOut,
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class ClientMobileBottomNav extends StatelessWidget {
  const ClientMobileBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final inactiveColor = palette.textPrimary.withValues(alpha: 0.78);
    const items = [
      (label: 'Buscar', icon: Icons.search_rounded),
      (label: 'Reservas', icon: Icons.flight_rounded),
      (label: 'Perfil', icon: Icons.person_rounded),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isActive = index == currentIndex;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => onSelect(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? palette.primary : palette.surfaceSoft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive ? palette.primary : palette.border,
                        ),
                        boxShadow:
                            isActive
                                ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 18,
                                    offset: Offset(0, 8),
                                  ),
                                ]
                                : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.icon,
                            size: 17,
                            color: isActive ? onPrimary : inactiveColor,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.label,
                                maxLines: 1,
                                style: TextStyle(
                                  color: isActive ? onPrimary : inactiveColor,
                                  fontWeight:
                                      isActive
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                  fontSize: 13,
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
            }),
          ),
        ),
      ),
    );
  }
}

class EyebrowLabel extends StatelessWidget {
  const EyebrowLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1.1,
        color: palette.textSecondary,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class SegmentedTripSelector extends StatelessWidget {
  const SegmentedTripSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final inactiveColor = palette.textPrimary.withValues(alpha: 0.74);
    const options = [
      (
        value: 'Solo ida',
        label: 'Solo ida',
        icon: Icons.flight_takeoff_rounded,
      ),
      (value: 'Ida y vuelta', label: 'Redondo', icon: Icons.sync_alt_rounded),
      (value: 'Multidestino', label: 'Multi', icon: Icons.alt_route_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3EAF1)),
      ),
      child: Row(
        children:
            options.map((option) {
              final isActive = option.value == value;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(option.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      vertical: 11,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? palette.primary : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            isActive
                                ? palette.primary
                                : const Color(0xFFE3EAF1),
                      ),
                      boxShadow:
                          isActive
                              ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.10),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                              : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          option.icon,
                          size: 15,
                          color: isActive ? onPrimary : inactiveColor,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          option.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isActive ? onPrimary : inactiveColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class ConciergeCard extends StatelessWidget {
  const ConciergeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 18),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class ConciergeField extends StatelessWidget {
  const ConciergeField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.leadingIcon,
    this.trailing,
    this.secondaryValue,
    this.placeholder = 'Seleccionar',
    this.helperText,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData? leadingIcon;
  final Widget? trailing;
  final String? secondaryValue;
  final String placeholder;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final isPlaceholder = value == placeholder;
    final fieldIconColor = palette.primary;
    final fieldChevronColor = palette.textPrimary.withValues(alpha: 0.70);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5EBF2)),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FB),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(leadingIcon, size: 20, color: fieldIconColor),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isPlaceholder
                        ? (helperText?.isNotEmpty == true
                            ? helperText!
                            : placeholder)
                        : value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          isPlaceholder
                              ? palette.textSecondary
                              : palette.textPrimary,
                      fontWeight:
                          isPlaceholder ? FontWeight.w600 : FontWeight.w800,
                      fontSize: 15,
                      height: 1.2,
                    ),
                  ),
                  if (!isPlaceholder && secondaryValue != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      secondaryValue!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: fieldChevronColor,
                  size: 24,
                ),
          ],
        ),
      ),
    );
  }
}

class LoadingBand extends StatelessWidget {
  const LoadingBand({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FilterChipButton extends StatelessWidget {
  const FilterChipButton({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isActive ? palette.primary : palette.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? palette.primary : palette.border,
          ),
          boxShadow:
              isActive
                  ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? palette.textOnAccent : palette.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
