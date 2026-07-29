import 'package:flutter/material.dart';

class ClientBookingConfirmationScreen extends StatelessWidget {
  const ClientBookingConfirmationScreen({
    super.key,
    required this.request,
    required this.onOpenTrips,
    this.showBackButton = true,
  });

  final Map<String, dynamic> request;
  final VoidCallback onOpenTrips;
  final bool showBackButton;

  static const _background = Color(0xFF07111D);
  static const _gold = Color(0xFFD8B15D);

  @override
  Widget build(BuildContext context) {
    final paymentConfirmed = _isPaymentConfirmed(request);

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _ConfirmationHero(
                paymentConfirmed: paymentConfirmed,
                showBackButton: showBackButton,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 24),
                  const _SuccessEmblem(),
                  const SizedBox(height: 18),
                  Text(
                    paymentConfirmed ? 'Pago confirmado' : 'Solicitud enviada',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    paymentConfirmed
                        ? 'Pago validado correctamente.'
                        : 'Proveedor notificado correctamente.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 18,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _RouteCapsule(
                    route: _routeLabel(request),
                    details: _flightDetails(request),
                  ),
                  const SizedBox(height: 26),
                  _ConfirmationTimeline(paymentConfirmed: paymentConfirmed),
                  const SizedBox(height: 24),
                  const _ConciergeMessage(),
                  const SizedBox(height: 24),
                  _PremiumActionButton(
                    label: 'Ver mis vuelos',
                    icon: Icons.flight_takeoff_rounded,
                    onTap: onOpenTrips,
                  ),
                  const SizedBox(height: 12),
                  const _ConciergeVisualButton(),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_none_rounded,
                        color: _gold,
                        size: 17,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Las actualizaciones llegarán automáticamente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .58),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _routeLabel(Map<String, dynamic> request) {
    final origin =
        request['origin']?.toString() ??
        request['base_airport']?.toString() ??
        'Origen';
    final destination = request['destination']?.toString() ?? 'Destino';
    return '${origin.toUpperCase()}  →  ${destination.toUpperCase()}';
  }

  String _flightDetails(Map<String, dynamic> request) {
    final passengers =
        request['passengers'] ??
        request['passenger_count'] ??
        request['capacity'] ??
        1;
    final rawDate =
        request['departure_date'] ??
        request['date'] ??
        request['start_date'] ??
        request['flight_date'];
    final rawTime =
        request['departure_time'] ??
        request['time'] ??
        request['start_time'] ??
        request['flight_time'];
    final pieces = <String>[
      '$passengers ${passengers.toString() == '1' ? 'pasajero' : 'pasajeros'}',
      if (_shortDate(rawDate).isNotEmpty) _shortDate(rawDate),
      if (_shortTime(rawTime).isNotEmpty) _shortTime(rawTime),
    ];
    return pieces.join('  •  ');
  }

  String _shortDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${parsed.day} ${months[parsed.month - 1]}';
  }

  String _shortTime(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '';
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(raw);
    if (match == null) return raw;
    final hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final minute = match.group(2) ?? '00';
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $suffix';
  }

  bool _isPaymentConfirmed(Map<String, dynamic> request) {
    final workflow =
        request['workflow_status']?.toString().trim().toLowerCase() ?? '';
    final status = request['status']?.toString().trim().toLowerCase() ?? '';
    final paymentStatus =
        request['payment_status']?.toString().trim().toLowerCase() ?? '';

    return workflow.contains('pago confirmado') ||
        workflow.contains('payment_confirmed') ||
        paymentStatus == 'paid' ||
        paymentStatus == 'pagado' ||
        status == 'payment_confirmed' ||
        status == 'paid';
  }
}

class _ConfirmationHero extends StatelessWidget {
  const _ConfirmationHero({
    required this.paymentConfirmed,
    required this.showBackButton,
  });

  final bool paymentConfirmed;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOut,
      builder: (_, value, child) => Opacity(opacity: value, child: child),
      child: SizedBox(
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/login/image.png', fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xE607111D),
                    Color(0xA007111D),
                    Color(0x5007111D),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x0007111D), Color(0xFF07111D)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [.62, 1],
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 24,
              child: Row(
                children: [
                  if (showBackButton) ...[
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: .32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .12),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const _ConfirmationBrand(),
                ],
              ),
            ),
            Positioned(
              top: 17,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF07111D).withValues(alpha: .58),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFD8B15D).withValues(alpha: .46),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bookmark_added_outlined,
                      color: Color(0xFFD8B15D),
                      size: 17,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      paymentConfirmed
                          ? 'Pago confirmado'
                          : 'Reserva registrada',
                      style: const TextStyle(
                        color: Color(0xFFD8B15D),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationBrand extends StatelessWidget {
  const _ConfirmationBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Color(0xFFD8B15D),
            BlendMode.srcIn,
          ),
          child: Image.asset('assets/LOGOINTERNO.png', width: 40, height: 32),
        ),
        const SizedBox(width: 7),
        const Text(
          'RED SKY\nG R O U P',
          style: TextStyle(
            color: Color(0xFFD8B15D),
            fontSize: 10,
            height: 1.1,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class _SuccessEmblem extends StatelessWidget {
  const _SuccessEmblem();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .7, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: Curves.elasticOut,
      builder: (_, value, child) => Transform.scale(scale: value, child: child),
      child: Center(
        child: SizedBox(
          width: 112,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ...const [
                Positioned(top: 8, left: 17, child: _GoldParticle(size: 4)),
                Positioned(top: 18, right: 15, child: _GoldParticle(size: 3)),
                Positioned(bottom: 12, left: 9, child: _GoldParticle(size: 3)),
                Positioned(bottom: 5, right: 20, child: _GoldParticle(size: 4)),
              ],
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF123B2B),
                  border: Border.all(
                    color: const Color(0xFFD8B15D),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF31D158).withValues(alpha: .26),
                      blurRadius: 28,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 47,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoldParticle extends StatelessWidget {
  const _GoldParticle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFD8B15D),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _RouteCapsule extends StatelessWidget {
  const _RouteCapsule({required this.route, required this.details});

  final String route;
  final String details;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .04),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: .09)),
            ),
            child: Text(
              route,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          details,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .62),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ConfirmationTimeline extends StatelessWidget {
  const _ConfirmationTimeline({required this.paymentConfirmed});

  final bool paymentConfirmed;

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('Solicitud enviada', true),
      ('Proveedor notificado', true),
      ('Revisión operativa', false),
      ('Confirmación', false),
      ('Contrato', false),
      ('Pago', paymentConfirmed),
      ('Vuelo listo', false),
    ];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder:
          (_, value, child) => Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: Opacity(opacity: value, child: child),
          ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF101C2D),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seguimiento',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < steps.length; index++)
              _TimelineStep(
                label: steps[index].$1,
                complete: steps[index].$2,
                isLast: index == steps.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.complete,
    required this.isLast,
  });

  final String label;
  final bool complete;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isLast ? 27 : 35,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        complete
                            ? const Color(0xFF31D158).withValues(alpha: .16)
                            : Colors.transparent,
                    border: Border.all(
                      color:
                          complete
                              ? const Color(0xFF31D158)
                              : Colors.white.withValues(alpha: .28),
                    ),
                  ),
                  child:
                      complete
                          ? const Icon(
                            Icons.check_rounded,
                            color: Color(0xFF31D158),
                            size: 12,
                          )
                          : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: const Color(0xFFD8B15D).withValues(alpha: .42),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              label,
              style: TextStyle(
                color:
                    complete
                        ? Colors.white
                        : Colors.white.withValues(alpha: .56),
                fontSize: 14,
                fontWeight: complete ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConciergeMessage extends StatelessWidget {
  const _ConciergeMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101C2D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD8B15D).withValues(alpha: .1),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Color(0xFFD8B15D),
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              'Nuestro equipo y el operador revisarán tu solicitud.\n\n'
              'Te notificaremos automáticamente cuando exista un cambio.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .76),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumActionButton extends StatefulWidget {
  const _PremiumActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_PremiumActionButton> createState() => _PremiumActionButtonState();
}

class _PremiumActionButtonState extends State<_PremiumActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 1.02 : 1,
        duration: const Duration(milliseconds: 130),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF0D184), Color(0xFFD8A943)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD8B15D).withValues(alpha: .14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: const Color(0xFF07111D), size: 22),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Color(0xFF07111D),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF07111D),
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConciergeVisualButton extends StatelessWidget {
  const _ConciergeVisualButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD8B15D).withValues(alpha: .7),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.headset_mic_outlined, color: Color(0xFFD8B15D), size: 21),
          SizedBox(width: 10),
          Text(
            'Contactar Concierge',
            style: TextStyle(
              color: Color(0xFFD8B15D),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
