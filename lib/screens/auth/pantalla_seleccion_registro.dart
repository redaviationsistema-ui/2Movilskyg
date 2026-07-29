import 'dart:ui';

import 'package:flutter/material.dart';

import 'pantalla_registro_cliente.dart';
import 'pantalla_registro_sobrecargo.dart';

class RegisterRoleSelectionScreen extends StatefulWidget {
  const RegisterRoleSelectionScreen({super.key});

  @override
  State<RegisterRoleSelectionScreen> createState() =>
      _RegisterRoleSelectionScreenState();
}

class _RegisterRoleSelectionScreenState
    extends State<RegisterRoleSelectionScreen> {
  _RegisterRole? _selectedRole;

  void _selectRole(_RegisterRole role) {
    setState(() => _selectedRole = role);
  }

  void _continue() {
    if (_selectedRole == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (_) =>
                _selectedRole == _RegisterRole.client
                    ? const ClientRegisterScreen()
                    : const CrewRegisterScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: _Palette.background,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _BackgroundLayer(),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(18, 14, 18, 182 + bottomInset),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _TopBar(onBack: () => Navigator.of(context).maybePop()),
                      const SizedBox(height: 14),
                      const _HeaderBlock(),
                      const SizedBox(height: 14),
                      const _BrandBanner(),
                      const SizedBox(height: 14),
                      _RoleCard(
                        title: 'Cliente',
                        description:
                            'Cotiza vuelos privados, administra tus reservas y accede a beneficios exclusivos.',
                        icon: Icons.person_rounded,
                        accent: _Palette.gold,
                        accentGlow: _Palette.goldGlow,
                        benefits: const [
                          _BenefitData(
                            icon: Icons.bolt_rounded,
                            title: 'Cotizacion\ninmediata',
                          ),
                          _BenefitData(
                            icon: Icons.headset_mic_rounded,
                            title: 'Concierge\n24/7',
                          ),
                          _BenefitData(
                            icon: Icons.workspace_premium_rounded,
                            title: 'Membresias\nexclusivas',
                          ),
                        ],
                        selected: _selectedRole == _RegisterRole.client,
                        onSelect: () => _selectRole(_RegisterRole.client),
                      ),
                      const SizedBox(height: 12),
                      _RoleCard(
                        title: 'Sobrecargo',
                        description:
                            'Gestiona vuelos asignados, tripulacion y operacion diaria.',
                        icon: Icons.badge_rounded,
                        accent: _Palette.blue,
                        accentGlow: _Palette.blueGlow,
                        benefits: const [
                          _BenefitData(
                            icon: Icons.flight_rounded,
                            title: 'Misiones\nasignadas',
                          ),
                          _BenefitData(
                            icon: Icons.calendar_month_rounded,
                            title: 'Disponibilidad\nde vuelos',
                          ),
                          _BenefitData(
                            icon: Icons.description_rounded,
                            title: 'Documentacion\ny reportes',
                          ),
                        ],
                        selected: _selectedRole == _RegisterRole.crew,
                        onSelect: () => _selectRole(_RegisterRole.crew),
                      ),
                      const SizedBox(height: 14),
                      const _SecurityCard(),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomContinueBar(
        selectedRole: _selectedRole,
        onContinue: _continue,
      ),
    );
  }
}

enum _RegisterRole { client, crew }

class _Palette {
  const _Palette._();

  static const background = Color(0xFF040B14);
  static const surface = Color(0xD9101925);
  static const surfaceAlt = Color(0xCC0B1522);
  static const text = Color(0xFFF9FAFB);
  static const textSoft = Color(0xFFC0C8D2);
  static const textMuted = Color(0xFF8993A1);
  static const line = Color(0x2CFFFFFF);
  static const lineStrong = Color(0x47FFFFFF);
  static const gold = Color(0xFFD9A84F);
  static const goldSoft = Color(0xFFF3D48E);
  static const goldGlow = Color(0x42D9A84F);
  static const blue = Color(0xFF5E92FF);
  static const blueGlow = Color(0x305E92FF);
  static const green = Color(0xFF5FD07D);
  static const greenSoft = Color(0xFF9AE59F);
}

class _BackgroundLayer extends StatelessWidget {
  const _BackgroundLayer();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF04101D),
                Color(0xFF07111C),
                Color(0xFF03070D),
              ],
            ),
          ),
        ),
        Positioned(
          top: 120,
          right: -40,
          child: _GlowOrb(color: _Palette.gold.withValues(alpha: .10), size: 220),
        ),
        Positioned(
          top: 280,
          left: -60,
          child: _GlowOrb(color: _Palette.blue.withValues(alpha: .09), size: 240),
        ),
        Positioned(
          bottom: 120,
          right: -20,
          child: _GlowOrb(color: Colors.white.withValues(alpha: .04), size: 200),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: Colors.white.withValues(alpha: .04),
            child: InkWell(
              onTap: onBack,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _Palette.lineStrong),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _Palette.text,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Crear cuenta',
          style: TextStyle(
            color: _Palette.text,
            fontSize: 34,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Selecciona el perfil que mejor se adapte a ti.',
          style: TextStyle(
            color: _Palette.textSoft,
            fontSize: 15.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _BrandBanner extends StatelessWidget {
  const _BrandBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 170,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _Palette.line),
            color: Colors.white.withValues(alpha: .03),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/login/image.png',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xF0040E1A),
                      const Color(0xD8040E1A),
                      const Color(0x52040E1A),
                    ],
                    stops: const [0, .46, 1],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/LOGOINTERNO.png',
                      width: 34,
                      height: 34,
                      fit: BoxFit.contain,
                      color: _Palette.gold,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                    const Spacer(),
                    const Text(
                      'Red Sky Group',
                      style: TextStyle(
                        color: _Palette.gold,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const SizedBox(
                      width: 150,
                      child: Text(
                        'Aviacion ejecutiva\na otro nivel',
                        style: TextStyle(
                          color: _Palette.textSoft,
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.accentGlow,
    required this.benefits,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final Color accentGlow;
  final List<_BenefitData> benefits;
  final bool selected;
  final VoidCallback onSelect;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 1.01 : 1,
        duration: const Duration(milliseconds: 160),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _Palette.surface,
                _Palette.surfaceAlt,
              ],
            ),
            border: Border.all(
              color:
                  widget.selected
                      ? widget.accent.withValues(alpha: .88)
                      : widget.accent.withValues(alpha: .65),
            ),
            boxShadow: [
              BoxShadow(
                color:
                    widget.selected
                        ? widget.accentGlow
                        : Colors.black.withValues(alpha: .22),
                blurRadius: widget.selected ? 24 : 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.accent.withValues(alpha: .65),
                      ),
                      gradient: RadialGradient(
                        colors: [
                          widget.accent.withValues(alpha: .18),
                          widget.accent.withValues(alpha: .05),
                        ],
                      ),
                    ),
                    child: Icon(widget.icon, color: widget.accent, size: 34),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: _Palette.text,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.7,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.description,
                          style: const TextStyle(
                            color: _Palette.textSoft,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ArrowCircle(
                    color: widget.accent,
                    filled: widget.selected,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: .06),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < widget.benefits.length; i++) ...[
                    Expanded(
                      child: _BenefitItem(
                        data: widget.benefits[i],
                        color: widget.accent,
                      ),
                    ),
                    if (i != widget.benefits.length - 1)
                      Container(
                        width: 1,
                        height: 44,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        color: Colors.white.withValues(alpha: .06),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              _SelectRoleButton(
                label: 'Seleccionar este perfil',
                color: widget.accent,
                selected: widget.selected,
                onTap: widget.onSelect,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrowCircle extends StatelessWidget {
  const _ArrowCircle({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color.withValues(alpha: .16) : Colors.transparent,
        border: Border.all(color: color.withValues(alpha: .75)),
      ),
      child: Icon(
        filled ? Icons.check_rounded : Icons.chevron_right_rounded,
        color: color,
        size: 24,
      ),
    );
  }
}

class _BenefitData {
  const _BenefitData({required this.icon, required this.title});

  final IconData icon;
  final String title;
}

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({required this.data, required this.color});

  final _BenefitData data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(data.icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          data.title,
          style: const TextStyle(
            color: _Palette.text,
            fontSize: 11.5,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SelectRoleButton extends StatelessWidget {
  const _SelectRoleButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: .75)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selected ? 'Perfil seleccionado' : label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: .06),
                    ),
                    child: Icon(
                      selected ? Icons.check_rounded : Icons.chevron_right_rounded,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _Palette.line),
            color: Colors.white.withValues(alpha: .03),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _Palette.green.withValues(alpha: .08),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: _Palette.green,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu informacion esta protegida',
                      style: TextStyle(
                        color: _Palette.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Datos cifrados, verificacion bancaria\ny cumplimiento PCI DSS.',
                      style: TextStyle(
                        color: _Palette.textSoft,
                        fontSize: 11.8,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: _Palette.green.withValues(alpha: .10),
                  border: Border.all(color: _Palette.green.withValues(alpha: .35)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, color: _Palette.greenSoft, size: 16),
                    SizedBox(width: 6),
                    Text(
                      '100% seguro',
                      style: TextStyle(
                        color: _Palette.greenSoft,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomContinueBar extends StatelessWidget {
  const _BottomContinueBar({
    required this.selectedRole,
    required this.onContinue,
  });

  final _RegisterRole? selectedRole;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final enabled = selectedRole != null;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final title =
        switch (selectedRole) {
          _RegisterRole.client => 'Cliente',
          _RegisterRole.crew => 'Sobrecargo',
          null => 'Selecciona un perfil',
        };
    final subtitle =
        enabled
            ? 'Listo para continuar con tu registro.'
            : 'para continuar con tu registro.';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 12 + bottomInset),
          decoration: BoxDecoration(
            color: const Color(0xF2101925),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: .06)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .05),
                ),
                child: Icon(
                  Icons.lock_rounded,
                  color: enabled ? _Palette.gold : _Palette.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: enabled ? _Palette.text : _Palette.textSoft,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _Palette.textMuted,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 160,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient:
                        enabled
                            ? const LinearGradient(
                              colors: [_Palette.goldSoft, _Palette.gold],
                            )
                            : LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: .08),
                                Colors.white.withValues(alpha: .06),
                              ],
                            ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: FilledButton(
                    onPressed: enabled ? onContinue : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      foregroundColor:
                          enabled ? const Color(0xFF11161D) : _Palette.textMuted,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continuar',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded, size: 22),
                      ],
                    ),
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
