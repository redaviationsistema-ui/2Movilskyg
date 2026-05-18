import 'package:flutter/material.dart';

class ClientMobileTopBar extends StatelessWidget {
  const ClientMobileTopBar({
    super.key,
    required this.userInitial,
    this.primaryLabel = 'Buscar',
  });

  final String userInitial;
  final String primaryLabel;

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
        Flexible(
          child: _PillAction(label: primaryLabel, onTap: () {}),
        ),
        const SizedBox(width: 10),
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Color(0xFF151515),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            userInitial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
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
    required this.userInitial,
    required this.child,
  });

  final String userInitial;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF6F1E8),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE8DED1))),
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

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8DED1))),
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isActive = index == currentIndex;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onSelect(index),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isActive
                            ? const Color(0xFF151515)
                            : const Color(0xFFF3EEE4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 18,
                        color:
                            isActive ? Colors.white : const Color(0xFF5C5246),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.label,
                        style: TextStyle(
                          color:
                              isActive ? Colors.white : const Color(0xFF5C5246),
                          fontWeight: FontWeight.w800,
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
    const options = ['Ida', 'Redondo', 'Multi-destino'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EBDF),
        borderRadius: BorderRadius.circular(999),
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color:
                          isActive
                              ? const Color(0xFF151515)
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      option,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            isActive ? Colors.white : const Color(0xFF2F2A25),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
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
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4DBCF)),
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
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF171717),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDD1C1)),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color:
                          value == 'Seleccionar'
                              ? const Color(0xFF7C7469)
                              : const Color(0xFF111111),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                trailing ??
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF6B6258),
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

class _PillAction extends StatelessWidget {
  const _PillAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF151515),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
