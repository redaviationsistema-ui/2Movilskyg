import 'package:flutter/material.dart';

const Color kWarmBg = Color(0xFFF7F3EC);
const Color kWarmCard = Color(0xFFFFFCF7);
const Color kWarmSoft = Color(0xFFF3EDE3);
const Color kWarmBorder = Color(0xFFE7DDCD);
const Color kWarmMuted = Color(0xFF857A6B);
const Color kWarmText = Color(0xFF2B241C);

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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kWarmCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kWarmBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: Image.asset('assets/logo.png', fit: BoxFit.contain),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: kWarmText,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: kWarmMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onSignOut,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kWarmCard,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: kWarmBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.logout_rounded, color: kWarmText, size: 20),
            ),
          ),
        ),
      ],
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
    return Material(
      color: kWarmBg,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              decoration: const BoxDecoration(
                color: kWarmBg,
                border: Border(bottom: BorderSide(color: kWarmBorder)),
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
    const items = [
      (label: 'Buscar', icon: Icons.search_rounded),
      (label: 'Reservas', icon: Icons.flight_rounded),
      (label: 'Perfil', icon: Icons.person_rounded),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: kWarmCard,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: kWarmBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x16000000),
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
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => onSelect(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF050505) : kWarmSoft,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color:
                              isActive ? const Color(0xFF050505) : kWarmBorder,
                        ),
                        boxShadow:
                            isActive
                                ? const [
                                  BoxShadow(
                                    color: Color(0x18000000),
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
                            size: 18,
                            color: isActive ? Colors.white : kWarmMuted,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.label,
                                maxLines: 1,
                                style: TextStyle(
                                  color: isActive ? Colors.white : kWarmMuted,
                                  fontWeight:
                                      isActive
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                  fontSize: 14,
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
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 1.1,
        color: Color(0xFF050505),
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
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: kWarmSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kWarmBorder),
      ),
      child: Row(
        children:
            options.map((option) {
              final isActive = option.value == value;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(option.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isActive
                              ? const Color(0xFF050505)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(19),
                      boxShadow:
                          isActive
                              ? const [
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 18,
                                  offset: Offset(0, 8),
                                ),
                              ]
                              : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          option.icon,
                          size: 17,
                          color: isActive ? Colors.white : kWarmMuted,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          option.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isActive ? Colors.white : kWarmMuted,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
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
    this.padding = const EdgeInsets.fromLTRB(22, 24, 22, 24),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: kWarmCard,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: kWarmBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 42,
            offset: Offset(0, 22),
          ),
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
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
    final isPlaceholder = value == placeholder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: kWarmMuted,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: kWarmBorder),
              color: kWarmCard,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leadingIcon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: kWarmSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      leadingIcon,
                      size: 20,
                      color: const Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isPlaceholder ? kWarmMuted : kWarmText,
                          fontWeight:
                              isPlaceholder ? FontWeight.w700 : FontWeight.w900,
                          fontSize: isPlaceholder ? 17 : 21,
                          height: 1.1,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (secondaryValue != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          secondaryValue!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: kWarmMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (helperText != null) ...[
                        const SizedBox(height: 7),
                        Text(
                          helperText!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: kWarmMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF050505),
                      size: 25,
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class LoadingBand extends StatelessWidget {
  const LoadingBand({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E7E7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF050505),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF050505),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF050505) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? const Color(0xFF050505) : const Color(0xFFE1E1E1),
          ),
          boxShadow:
              isActive
                  ? const [
                    BoxShadow(
                      color: Color(0x16000000),
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
            color: isActive ? Colors.white : const Color(0xFF050505),
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
