import 'package:flutter/material.dart';

class ClientMobileTopBar extends StatelessWidget {
  const ClientMobileTopBar({super.key, required this.userInitial});

  final String userInitial;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/logo.png', width: 42, height: 28),
              const SizedBox(width: 6),
              const Text(
                'sky\nGroup',
                style: TextStyle(
                  fontSize: 10,
                  height: 0.9,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF151515),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F2E8),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE3D8C8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            userInitial,
            style: const TextStyle(
              color: Color(0xFF151515),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {},
          child: Ink(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFF151515),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.menu_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class ClientMobileScreenShell extends StatelessWidget {
  const ClientMobileScreenShell({
    super.key,
    required this.userInitial,
    required this.child,
  });

  final String userInitial;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F2EA),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0x0F141414))),
              ),
              child: ClientMobileTopBar(userInitial: userInitial),
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
      (label: 'Vuelos', icon: Icons.flight_rounded),
      (label: 'Cuenta', icon: Icons.person_rounded),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color: const Color(0xEBFFFFFF),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0x0F141414)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 40,
                offset: Offset(0, 18),
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
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onSelect(index),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isActive
                                ? const Color(0xFF151515)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.icon,
                            size: 18,
                            color:
                                isActive
                                    ? Colors.white
                                    : const Color(0xFF6F675D),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.label,
                            style: TextStyle(
                              color:
                                  isActive
                                      ? Colors.white
                                      : const Color(0xFF6F675D),
                              fontWeight:
                                  isActive ? FontWeight.w900 : FontWeight.w700,
                              fontSize: 15,
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
        letterSpacing: 0.7,
        color: Color(0xFF9A6F28),
        fontWeight: FontWeight.w700,
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
    const options = ['Solo ida', 'Ida y vuelta', 'Multidestino'];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EBDF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children:
            options.map((option) {
              final isActive = option == value;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(option),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isActive
                              ? const Color(0xFF151515)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow:
                          isActive
                              ? const [
                                BoxShadow(
                                  color: Color(0x2E000000),
                                  blurRadius: 20,
                                  offset: Offset(0, 8),
                                ),
                              ]
                              : null,
                    ),
                    child: Text(
                      option,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            isActive ? Colors.white : const Color(0xFF2F2A25),
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x0F141414)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 60,
            offset: Offset(0, 24),
          ),
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 20,
            offset: Offset(0, 8),
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
    this.trailing,
    this.secondaryValue,
    this.placeholder = 'Seleccionar',
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? secondaryValue;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = value == placeholder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF171717),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x0F141414)),
              color: const Color(0xFFFBF8F2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          color:
                              isPlaceholder
                                  ? const Color(0xFF7C7469)
                                  : const Color(0xFF111111),
                          fontWeight:
                              isPlaceholder ? FontWeight.w600 : FontWeight.w800,
                          fontSize: isPlaceholder ? 18 : 22,
                          height: 1.1,
                        ),
                      ),
                      if (secondaryValue != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          secondaryValue!,
                          style: const TextStyle(
                            color: Color(0xFF766D61),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF6F675D),
                      size: 24,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4DBCF)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF2A2A2A),
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF151515) : const Color(0xFFF3EEE4),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF2C2823),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
