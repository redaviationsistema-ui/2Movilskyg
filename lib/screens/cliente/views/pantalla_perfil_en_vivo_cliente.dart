import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/acceso_comercial_cliente.dart';
import '../../../core/client_workflow_status.dart';
import '../../../providers/proveedor_autenticacion.dart';
import '../../../providers/proveedor_reservaciones.dart';

class ClientLiveProfileScreen extends StatefulWidget {
  const ClientLiveProfileScreen({
    super.key,
    this.showBackButton = true,
    this.hasExternalTopBanner = false,
    this.onCommercialAccessTap,
  });

  final bool showBackButton;
  final bool hasExternalTopBanner;
  final VoidCallback? onCommercialAccessTap;

  @override
  State<ClientLiveProfileScreen> createState() =>
      _ClientLiveProfileScreenState();
}

class _ClientLiveProfileScreenState extends State<ClientLiveProfileScreen> {
  static const _background = Color(0xFF07111D);
  static const _card = Color(0xFF101C2D);
  static const _gold = Color(0xFFD8B25D);
  static const _danger = Color(0xFFE65362);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final reservation = context.watch<ReservationProvider>();
    final access = auth.accessData ?? const <String, dynamic>{};
    final dashboard = reservation.dashboardData ?? const <String, dynamic>{};
    final metrics = _nestedMap(dashboard['metrics'] ?? dashboard['summary']);
    final user = auth.user;
    final commercialState = resolveCommercialAccessState(access);

    final displayName =
        auth.displayName.trim().isNotEmpty
            ? auth.displayName.trim()
            : 'Cliente';
    final initial =
        displayName.isEmpty ? 'C' : displayName.characters.first.toUpperCase();
    final email =
        user?.email.trim().isNotEmpty == true
            ? user!.email.trim()
            : 'Sin correo';
    final phone =
        user?.phone.trim().isNotEmpty == true
            ? user!.phone.trim()
            : 'Sin teléfono';
    final membership = _planLabel(access);
    final active =
        !commercialState.isExpired &&
        !commercialState.isSuspended &&
        (commercialState.canReserve || commercialState.isPastDue);
    final membershipStatusLabel = _commercialStatusLabel(commercialState);
    final membershipRenewalTitle = _commercialRenewalTitle(commercialState);
    final membershipActionLabel = commercialState.paymentActionLabel;
    final requests = reservation.flightRequests;
    final requestsCount =
        (metrics['solicitudes'] ?? metrics['requests'] ?? requests.length)
            .toString();
    final flightsCount =
        (metrics['vuelos'] ??
                metrics['flights'] ??
                metrics['completed_flights'] ??
                0)
            .toString();
    final validations = _validationItems(
      auth: auth,
      email: email,
      membershipReady: _hasMembership(access),
      accessReady: commercialState.canReserve,
    );

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        top: !widget.hasExternalTopBanner,
        bottom: false,
        child: RefreshIndicator(
          color: _gold,
          backgroundColor: _card,
          onRefresh: _refreshProfile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
            children: [
              _ProfileReveal(
                order: 0,
                child: _ProfileHeader(
                  showBackButton: widget.showBackButton,
                  onBack: () => Navigator.pop(context),
                  onEdit: _showEditMessage,
                  onRefresh: _refreshProfile,
                ),
              ),
              const SizedBox(height: 18),
              _ProfileReveal(
                order: 1,
                child: _ProfileHero(
                  initial: initial,
                  name: displayName,
                  email: email,
                  phone: phone,
                  membership: _memberTitle(membership),
                  active: active,
                  statusLabel: membershipStatusLabel,
                ),
              ),
              const SizedBox(height: 20),
              const _ProfileReveal(order: 2, child: _SectionTitle('Resumen')),
              const SizedBox(height: 10),
              _ProfileReveal(
                order: 3,
                child: _SummaryGrid(
                  flights: flightsCount,
                  requests: requestsCount,
                  status: membershipStatusLabel,
                  membership: _shortMembership(membership),
                ),
              ),
              const SizedBox(height: 22),
              const _ProfileReveal(
                order: 4,
                child: _SectionTitle('Validaciones'),
              ),
              const SizedBox(height: 10),
              _ProfileReveal(
                order: 5,
                child: _ValidationCircles(items: validations),
              ),
              const SizedBox(height: 22),
              const _ProfileReveal(order: 6, child: _SectionTitle('Actividad')),
              const SizedBox(height: 10),
              _ProfileReveal(
                order: 7,
                child: _ActivityTimeline(requests: requests),
              ),
              const SizedBox(height: 22),
              _ProfileReveal(
                order: 8,
                child: _MembershipCard(
                  membership: _memberTitle(membership),
                  active: active,
                  statusLabel: membershipStatusLabel,
                  renewalTitle: membershipRenewalTitle,
                  renewal: _renewalLabel(access, commercialState),
                  actionLabel: membershipActionLabel,
                  onManage:
                      widget.onCommercialAccessTap ?? _showMembershipMessage,
                ),
              ),
              const SizedBox(height: 22),
              _ProfileReveal(
                order: 9,
                child: _ScaleButton(
                  onTap: _showEditMessage,
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _gold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Editar perfil',
                      style: TextStyle(
                        color: Color(0xFF111820),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ProfileReveal(
                order: 10,
                child: _ScaleButton(
                  onTap: auth.signOut,
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _gold),
                    ),
                    child: const Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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

  Future<void> _refreshProfile() async {
    await Future.wait([
      context.read<AuthProvider>().refreshCommercialAccessStatus(),
      context.read<ReservationProvider>().loadClientWorkspaceData(force: true),
    ]);
  }

  void _showEditMessage() {
    _showMessage('Edición de perfil disponible próximamente.');
  }

  void _showMembershipMessage() {
    final access = context.read<AuthProvider>().accessData ?? const {};
    final state = resolveCommercialAccessState(access);
    _showMessage(state.accessBannerMessage);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _card,
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: _gold.withValues(alpha: .24)),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
  }

  Map<String, dynamic> _nestedMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String _identityStatus(Map<String, dynamic>? payload) {
    final profile = _nestedMap(payload?['profile']);
    final verified =
        payload?['identity_verified'] ?? profile['identity_verified'];
    if (verified == true || verified == 1 || verified == '1') {
      return 'Verificada';
    }
    return (payload?['identity_verification_status'] ??
                payload?['identity_status'] ??
                profile['identity_verification_status'])
            ?.toString()
            .trim() ??
        'Pendiente';
  }

  bool _hasMembership(Map<String, dynamic> access) {
    final state = resolveCommercialAccessState(access);
    if (state.hasPaidAccess || state.canReserve) return true;
    for (final source in [access['subscription'], access['membership']]) {
      if (source is! Map) continue;
      final status = source['status']?.toString().trim().toLowerCase();
      if (status == 'active' || status == 'activo') return true;
    }
    return false;
  }

  String _planLabel(Map<String, dynamic> access) {
    final subscription = access['subscription'];
    if (subscription is Map) {
      final value = subscription['plan_name'] ?? subscription['plan'];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    final name = access['plan_name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    return _hasMembership(access) ? 'Executive' : 'Sin membresía';
  }

  String _memberTitle(String membership) {
    final clean =
        membership
            .replaceAll(RegExp(r'membres[ií]a', caseSensitive: false), '')
            .trim();
    if (clean.toLowerCase().contains('sin')) return clean;
    return clean.toLowerCase().contains('member') ? clean : '$clean Member';
  }

  String _shortMembership(String membership) {
    final clean =
        membership
            .replaceAll(RegExp(r'membres[ií]a', caseSensitive: false), '')
            .trim();
    return clean.isEmpty ? 'Executive' : clean;
  }

  String _renewalLabel(
    Map<String, dynamic> access,
    CommercialAccessState state,
  ) {
    if (state.isExpired) {
      return state.expiresAtLabel.trim().isNotEmpty
          ? 'Vencido ${state.expiresAtLabel}'
          : 'Vencido';
    }
    if (state.isSuspended) {
      return state.graceEndsAtLabel.trim().isNotEmpty
          ? 'Suspendido ${state.graceEndsAtLabel}'
          : 'Suspendido';
    }
    if (state.isPastDue) {
      return state.graceEndsAtLabel.trim().isNotEmpty
          ? 'Gracia hasta ${state.graceEndsAtLabel}'
          : 'Pago pendiente';
    }
    if (state.expiresAtLabel.trim().isNotEmpty) return state.expiresAtLabel;
    final subscription = access['subscription'];
    final raw =
        subscription is Map
            ? subscription['current_period_end'] ??
                subscription['expires_at'] ??
                subscription['renewal_date']
            : null;
    final parsed = raw == null ? null : DateTime.tryParse(raw.toString());
    if (parsed == null) return 'Por confirmar';
    return DateFormat('dd MMM yyyy', 'es_MX').format(parsed);
  }

  String _commercialStatusLabel(CommercialAccessState state) {
    if (state.isExpired) return 'Vencido';
    if (state.isSuspended) return 'Suspendido';
    if (state.isPastDue) return 'Pago pendiente';
    if (state.canReserve) return 'Activo';
    return 'Pendiente';
  }

  String _commercialRenewalTitle(CommercialAccessState state) {
    if (state.isExpired) return 'Venció';
    if (state.isSuspended) return 'Gracia';
    if (state.isPastDue) return 'Límite';
    return 'Renueva';
  }

  List<_ValidationData> _validationItems({
    required AuthProvider auth,
    required String email,
    required bool membershipReady,
    required bool accessReady,
  }) {
    final identity = _identityStatus(auth.userPayload).toLowerCase();
    return [
      _ValidationData(
        label: 'Correo',
        status: email.contains('@') ? 'Verificado' : 'Pendiente',
        icon: Icons.mail_outline_rounded,
        color: email.contains('@') ? const Color(0xFF37CE88) : _gold,
      ),
      _ValidationData(
        label: 'Identidad',
        status:
            identity.contains('verificada') || identity.contains('verified')
                ? 'Verificada'
                : 'Pendiente',
        icon: Icons.badge_outlined,
        color:
            identity.contains('rechaz') || identity.contains('error')
                ? _danger
                : identity.contains('verificada') ||
                    identity.contains('verified')
                ? const Color(0xFF37CE88)
                : _gold,
      ),
      _ValidationData(
        label: 'Membresía',
        status: membershipReady ? 'Activa' : 'Pendiente',
        icon: Icons.workspace_premium_outlined,
        color: membershipReady ? const Color(0xFF37CE88) : _gold,
      ),
      _ValidationData(
        label: 'Acceso',
        status: accessReady ? 'Activo' : 'Pendiente',
        icon: Icons.lock_open_rounded,
        color: accessReady ? const Color(0xFF37CE88) : _gold,
      ),
    ];
  }
}

class _ProfileReveal extends StatefulWidget {
  const _ProfileReveal({required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  State<_ProfileReveal> createState() => _ProfileRevealState();
}

class _ProfileRevealState extends State<_ProfileReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curve);
    _offset = Tween<Offset>(
      begin: const Offset(0, .08),
      end: Offset.zero,
    ).animate(curve);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (MediaQuery.maybeDisableAnimationsOf(context) == true) {
        _controller.value = 1;
        return;
      }
      await Future<void>.delayed(Duration(milliseconds: 45 * widget.order));
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.showBackButton,
    required this.onBack,
    required this.onEdit,
    required this.onRefresh,
  });

  final bool showBackButton;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBackButton) ...[
          _GlassCircle(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Volver',
            onTap: onBack,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Perfil',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Todo listo para volar.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .7),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        _GlassCircle(
          icon: Icons.edit_outlined,
          tooltip: 'Editar perfil',
          onTap: onEdit,
        ),
        const SizedBox(width: 10),
        _GlassCircle(
          icon: Icons.refresh_rounded,
          tooltip: 'Actualizar',
          onTap: onRefresh,
        ),
      ],
    );
  }
}

class _GlassCircle extends StatelessWidget {
  const _GlassCircle({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          style: IconButton.styleFrom(
            fixedSize: const Size(42, 42),
            foregroundColor: const Color(0xFFD8B25D),
            backgroundColor: const Color(0xFF101C2D).withValues(alpha: .74),
            side: BorderSide(color: Colors.white.withValues(alpha: .08)),
          ),
          icon: Icon(icon, size: 23),
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.initial,
    required this.name,
    required this.email,
    required this.phone,
    required this.membership,
    required this.active,
    required this.statusLabel,
  });

  final String initial;
  final String name;
  final String email;
  final String phone;
  final String membership;
  final bool active;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder:
          (_, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - value)),
              child: child,
            ),
          ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF101C2D), Color(0xFF162A45)],
            ),
            image: const DecorationImage(
              image: AssetImage('assets/login/image.png'),
              fit: BoxFit.cover,
              alignment: Alignment(.45, .1),
              opacity: .26,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF07111D).withValues(alpha: .82),
                        border: Border.all(
                          color: const Color(0xFFD8B25D),
                          width: 1.4,
                        ),
                      ),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              height: 1.08,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            membership,
                            style: const TextStyle(
                              color: Color(0xFFD8B25D),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 7),
                          _StatusChip(
                            active: active,
                            label: 'Cuenta $statusLabel',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 335;
                    final mail = _ContactLine(
                      icon: Icons.mail_outline_rounded,
                      value: email,
                    );
                    final phoneLine = _ContactLine(
                      icon: Icons.phone_outlined,
                      value: phone,
                    );
                    if (narrow) {
                      return Column(
                        children: [mail, const SizedBox(height: 7), phoneLine],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: mail),
                        Container(
                          width: 1,
                          height: 24,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          color: Colors.white.withValues(alpha: .14),
                        ),
                        Expanded(child: phoneLine),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active, required this.label});

  final bool active;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF37CE88) : const Color(0xFFD8B25D);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          active ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
          color: color,
          size: 15,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFD8B25D), size: 18),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            value,
            softWrap: true,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .75),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -.4,
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.flights,
    required this.requests,
    required this.status,
    required this.membership,
  });

  final String flights;
  final String requests;
  final String status;
  final String membership;

  @override
  Widget build(BuildContext context) {
    final items = [
      _SummaryData(Icons.flight_takeoff_rounded, flights, 'Vuelos'),
      _SummaryData(Icons.description_outlined, requests, 'Solicitudes'),
      _SummaryData(Icons.verified_user_outlined, status, 'Estado'),
      _SummaryData(Icons.workspace_premium_outlined, membership, 'Membresía'),
    ];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder:
          (_, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 10 * (1 - value)),
              child: child,
            ),
          ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF192A40),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF304158)),
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            return Expanded(
              child: Row(
                children: [
                  if (index > 0)
                    Container(
                      width: 1,
                      height: 42,
                      color: Colors.white.withValues(alpha: .08),
                    ),
                  Expanded(child: _SummaryColumn(item: items[index])),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({required this.item});

  final _SummaryData item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, color: const Color(0xFFD8B25D), size: 17),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .66),
              fontSize: 10,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryData {
  const _SummaryData(this.icon, this.value, this.label);

  final IconData icon;
  final String value;
  final String label;
}

class _ValidationCircles extends StatelessWidget {
  const _ValidationCircles({required this.items});

  final List<_ValidationData> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101C2D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Row(
        children:
            items.map((item) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon, color: item.color, size: 18),
                      const SizedBox(height: 5),
                      Text(
                        item.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .82),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.status,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          color: item.color,
                          fontSize: 9.5,
                          height: 1.05,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _ValidationData {
  const _ValidationData({
    required this.label,
    required this.status,
    required this.icon,
    required this.color,
  });

  final String label;
  final String status;
  final IconData icon;
  final Color color;
}

class _ActivityTimeline extends StatelessWidget {
  const _ActivityTimeline({required this.requests});

  final List<Map<String, dynamic>> requests;

  @override
  Widget build(BuildContext context) {
    final entries =
        requests
            .take(2)
            .map(
              (request) => _ActivityData(
                date: _activityDate(request),
                title: _activityRoute(request),
                detail: clientWorkflowLabelForStage(
                  resolveClientWorkflowStage(request),
                ),
                icon: Icons.flight_takeoff_rounded,
              ),
            )
            .toList();

    if (entries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF101C2D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Text(
          'Sin actividad reciente.',
          style: TextStyle(color: Colors.white.withValues(alpha: .66)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101C2D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        children: List.generate(entries.length, (index) {
          final entry = entries[index];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(entry.icon, color: const Color(0xFFD8B25D), size: 19),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${entry.detail} · ${entry.date}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .62),
                              fontSize: 12,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (index != entries.length - 1)
                Divider(height: 1, color: Colors.white.withValues(alpha: .08)),
            ],
          );
        }),
      ),
    );
  }

  static String _activityRoute(Map<String, dynamic> request) {
    final origin = request['origin']?.toString().trim() ?? '';
    final destination = request['destination']?.toString().trim() ?? '';
    if (origin.isEmpty && destination.isEmpty) return 'Vuelo privado';
    return '$origin → $destination';
  }

  static String _activityDate(Map<String, dynamic> request) {
    final raw =
        request['updated_at'] ??
        request['created_at'] ??
        request['departure_datetime'];
    final parsed = raw == null ? null : DateTime.tryParse(raw.toString());
    if (parsed == null) return 'Reciente';
    final difference = DateTime.now().difference(parsed).inDays;
    if (difference <= 0) return 'Hoy';
    if (difference == 1) return 'Ayer';
    return 'Hace $difference días';
  }
}

class _ActivityData {
  const _ActivityData({
    required this.date,
    required this.title,
    required this.detail,
    required this.icon,
  });

  final String date;
  final String title;
  final String detail;
  final IconData icon;
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({
    required this.membership,
    required this.active,
    required this.statusLabel,
    required this.renewalTitle,
    required this.renewal,
    required this.actionLabel,
    required this.onManage,
  });

  final String membership;
  final bool active;
  final String statusLabel;
  final String renewalTitle;
  final String renewal;
  final String actionLabel;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final normalized = statusLabel.toLowerCase();
    final statusColor =
        normalized.contains('venc') || normalized.contains('suspend')
            ? const Color(0xFFE65362)
            : active
            ? const Color(0xFF37CE88)
            : const Color(0xFFD8B25D);
    final action = GestureDetector(
      onTap: onManage,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFD8B25D),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          actionLabel,
          style: const TextStyle(
            color: Color(0xFF111820),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    final details = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          membership,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 10,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Text(
              '$renewalTitle: $renewal',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .78),
                fontSize: 12,
                height: 1.15,
              ),
            ),
          ],
        ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          image: const DecorationImage(
            image: AssetImage('assets/profile_membership_cabin.png'),
            fit: BoxFit.cover,
            opacity: .42,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 330;
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [details, const SizedBox(height: 12), action],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: details),
                const SizedBox(width: 12),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScaleButton extends StatefulWidget {
  const _ScaleButton({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<_ScaleButton> {
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
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
