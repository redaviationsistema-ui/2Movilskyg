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
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE7E7E7)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(7),
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sky Group',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                      color: Color(0xFF050505),
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Private aviation',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF777777),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF050505),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF050505)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            userInitial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 10),
       
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
      color: const Color(0xFFF7F7F7),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF7F7F7),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE8E8E8)),
                ),
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE7E7E7)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x20000000),
                blurRadius: 38,
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
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => onSelect(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isActive
                                ? const Color(0xFF050505)
                                : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color:
                              isActive
                                  ? const Color(0xFF050505)
                                  : const Color(0xFFEDEDED),
                        ),
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
                                    : const Color(0xFF646464),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.label,
                            style: TextStyle(
                              color:
                                  isActive
                                      ? Colors.white
                                      : const Color(0xFF646464),
                              fontWeight:
                                  isActive ? FontWeight.w900 : FontWeight.w700,
                              fontSize: 14,
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
    const options = ['Solo ida', 'Ida y vuelta', 'Multidestino'];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7E7E7)),
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
                    child: Text(
                      option,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            isActive ? Colors.white : const Color(0xFF505050),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: -0.2,
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
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE7E7E7)),
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
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: Color(0xFF565656),
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
              border: Border.all(color: const Color(0xFFE4E4E4)),
              color: const Color(0xFFF8F8F8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              isPlaceholder
                                  ? const Color(0xFF8A8A8A)
                                  : const Color(0xFF050505),
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
                            color: Color(0xFF6F6F6F),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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