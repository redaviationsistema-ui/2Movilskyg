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
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 132),
            children: [
              _ProfileHeader(
                showBackButton: widget.showBackButton,
                onBack: () => Navigator.pop(context),
                onEdit: _showEditMessage,
                onRefresh: _refreshProfile,
              ),
              const SizedBox(height: 24),
              _ProfileHero(
                initial: initial,
                name: displayName,
                email: email,
                phone: phone,
                membership: _memberTitle(membership),
                active: active,
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Resumen'),
              const SizedBox(height: 14),
              _SummaryGrid(
                flights: flightsCount,
                requests: requestsCount,
                active: active,
                membership: _shortMembership(membership),
              ),
              const SizedBox(height: 28),
              const _SectionTitle('Validaciones'),
              const SizedBox(height: 18),
              _ValidationCircles(items: validations),
              const SizedBox(height: 30),
              const _SectionTitle('Actividad'),
              const SizedBox(height: 16),
              _ActivityTimeline(requests: requests),
              const SizedBox(height: 28),
              _MembershipCard(
                membership: _memberTitle(membership),
                active: active,
                statusLabel: membershipStatusLabel,
                renewalTitle: membershipRenewalTitle,
                renewal: _renewalLabel(access, commercialState),
                actionLabel: membershipActionLabel,
                onManage:
                    widget.onCommercialAccessTap ?? _showMembershipMessage,
              ),
              const SizedBox(height: 28),
              const _SectionTitle('Preferencias'),
              const SizedBox(height: 8),
              _PreferencesList(
                paymentMethod: reservation.paymentMethod ?? 'Por definir',
                onTap: _showPreferenceMessage,
              ),
              const SizedBox(height: 28),
              _ScaleButton(
                onTap: _showEditMessage,
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(18),
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
              const SizedBox(height: 12),
              _ScaleButton(
                onTap: auth.signOut,
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
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

  void _showPreferenceMessage(String label) {
    _showMessage('$label disponible próximamente.');
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
        icon: Icons.mail_outline_rounded,
        ready: email.contains('@'),
      ),
      _ValidationData(
        label: 'Identidad',
        icon: Icons.badge_outlined,
        ready: identity.contains('verificada') || identity.contains('verified'),
      ),
      _ValidationData(
        label: 'Membresía',
        icon: Icons.workspace_premium_outlined,
        ready: membershipReady,
      ),
      _ValidationData(
        label: 'Acceso',
        icon: Icons.lock_open_rounded,
        ready: accessReady,
      ),
    ];
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
                  fontSize: 18,
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
            fixedSize: const Size(52, 52),
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
  });

  final String initial;
  final String name;
  final String email;
  final String phone;
  final String membership;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
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
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          height: 270,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF101C2D), Color(0xFF162A45)],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: MediaQuery.sizeOf(context).width * .46,
                child: Image.asset(
                  'assets/login/image.png',
                  fit: BoxFit.cover,
                  alignment: const Alignment(.45, .1),
                  filterQuality: FilterQuality.high,
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: [0, .62, 1],
                    colors: [
                      Color(0xFF101C2D),
                      Color(0xEE101C2D),
                      Color(0x55101C2D),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .08),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 66,
                      height: 66,
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
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 245),
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          height: 1.02,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      membership,
                      style: const TextStyle(
                        color: Color(0xFFD8B25D),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          active
                              ? Icons.check_circle_outline_rounded
                              : Icons.schedule_rounded,
                          color:
                              active
                                  ? const Color(0xFF35D06F)
                                  : const Color(0xFFD8B25D),
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          active ? 'Cuenta activa' : 'Cuenta pendiente',
                          style: TextStyle(
                            color:
                                active
                                    ? const Color(0xFF35D06F)
                                    : const Color(0xFFD8B25D),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: _ContactLine(
                            icon: Icons.mail_outline_rounded,
                            value: email,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 26,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: Colors.white.withValues(alpha: .14),
                        ),
                        Expanded(
                          child: _ContactLine(
                            icon: Icons.phone_outlined,
                            value: phone,
                          ),
                        ),
                      ],
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
    required this.active,
    required this.membership,
  });

  final String flights;
  final String requests;
  final bool active;
  final String membership;

  @override
  Widget build(BuildContext context) {
    final items = [
      _SummaryData(Icons.flight_takeoff_rounded, flights, 'Vuelos'),
      _SummaryData(Icons.description_outlined, requests, 'Solicitudes'),
      _SummaryData(
        Icons.verified_user_outlined,
        active ? 'Activo' : 'Pendiente',
        'Estado',
      ),
      _SummaryData(Icons.workspace_premium_outlined, membership, 'Membresía'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 116,
      ),
      itemBuilder: (_, index) {
        final item = items[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 380 + index * 70),
          curve: Curves.easeOutCubic,
          builder:
              (_, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - value)),
                  child: child,
                ),
              ),
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: const Color(0xFF101C2D),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: Row(
              children: [
                Icon(item.icon, color: const Color(0xFFD8B25D), size: 25),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .65),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children:
          items.map((item) {
            final color =
                item.ready ? const Color(0xFF35D06F) : const Color(0xFFD8B25D);
            return Expanded(
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF101C2D),
                          border: Border.all(
                            color: color.withValues(alpha: .32),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: .14),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Icon(item.icon, color: const Color(0xFFD8B25D)),
                      ),
                      Positioned(
                        right: -2,
                        bottom: 1,
                        child: Container(
                          width: 19,
                          height: 19,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF07111D),
                            border: Border.all(color: color, width: 1.5),
                          ),
                          child: Icon(
                            item.ready ? Icons.check_rounded : Icons.more_horiz,
                            color: color,
                            size: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .78),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }
}

class _ValidationData {
  const _ValidationData({
    required this.label,
    required this.icon,
    required this.ready,
  });

  final String label;
  final IconData icon;
  final bool ready;
}

class _ActivityTimeline extends StatelessWidget {
  const _ActivityTimeline({required this.requests});

  final List<Map<String, dynamic>> requests;

  @override
  Widget build(BuildContext context) {
    final entries =
        requests.isEmpty
            ? const [
              _ActivityData(
                date: 'Hoy',
                title: 'Perfil actualizado',
                detail: 'Tu cuenta está al día',
                icon: Icons.person_outline_rounded,
              ),
            ]
            : requests
                .take(3)
                .map(
                  (request) => _ActivityData(
                    date: _activityDate(request),
                    title: clientWorkflowLabelForStage(
                      resolveClientWorkflowStage(request),
                    ),
                    detail: _activityRoute(request),
                    icon: Icons.flight_takeoff_rounded,
                  ),
                )
                .toList();

    return Column(
      children: List.generate(entries.length, (index) {
        final entry = entries[index];
        final last = index == entries.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 26,
                child: Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF101C2D),
                        border: Border.all(color: const Color(0xFFD8B25D)),
                      ),
                      child: Icon(
                        entry.icon,
                        color: const Color(0xFFD8B25D),
                        size: 13,
                      ),
                    ),
                    if (!last)
                      Expanded(
                        child: Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          color: const Color(0xFFD8B25D).withValues(alpha: .35),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: last ? 0 : 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.date,
                        style: const TextStyle(
                          color: Color(0xFFD8B25D),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        entry.detail,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .62),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 190,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/profile_membership_cabin.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xF5101C2D), Color(0xA8101C2D)],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(21),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    membership,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              active
                                  ? const Color(0xFF35D06F)
                                  : const Color(0xFFD8B25D),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color:
                              active
                                  ? const Color(0xFF35D06F)
                                  : const Color(0xFFD8B25D),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              renewalTitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .58),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              renewal,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onManage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFD8B25D)),
                          ),
                          child: Text(
                            actionLabel,
                            style: TextStyle(
                              color: Color(0xFFD8B25D),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferencesList extends StatelessWidget {
  const _PreferencesList({required this.paymentMethod, required this.onTap});

  final String paymentMethod;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.notifications_none_rounded, 'Notificaciones', 'Activadas'),
      (Icons.language_rounded, 'Idioma', 'Español'),
      (Icons.credit_card_outlined, 'Método de pago', paymentMethod),
      (Icons.folder_outlined, 'Documentos', ''),
    ];

    return Column(
      children: List.generate(items.length, (index) {
        final item = items[index];
        return Column(
          children: [
            InkWell(
              onTap: () => onTap(item.$2),
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Icon(item.$1, color: const Color(0xFFD8B25D), size: 21),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        item.$2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (item.$3.isNotEmpty)
                      Flexible(
                        child: Text(
                          item.$3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .55),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(width: 7),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: .42),
                    ),
                  ],
                ),
              ),
            ),
            if (index != items.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: .08),
              ),
          ],
        );
      }),
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
