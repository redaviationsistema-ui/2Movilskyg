import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/acceso_comercial_cliente.dart';
import '../../../core/app_theme.dart';
import '../../../core/client_workflow_status.dart';
import '../../../providers/proveedor_autenticacion.dart';
import '../../../providers/proveedor_reservaciones.dart';
import '../tema_cliente.dart';
import '../widgets/widgets_experiencia_cliente.dart';

class ClientLiveProfileScreen extends StatefulWidget {
  const ClientLiveProfileScreen({
    super.key,
    this.showBackButton = true,
    this.hasExternalTopBanner = false,
  });

  final bool showBackButton;
  final bool hasExternalTopBanner;

  @override
  State<ClientLiveProfileScreen> createState() =>
      _ClientLiveProfileScreenState();
}

class _ClientLiveProfileScreenState extends State<ClientLiveProfileScreen> {
  _ProfileTab _activeTab = _ProfileTab.dashboard;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    final auth = context.watch<AuthProvider>();
    final reservation = context.watch<ReservationProvider>();
    final access = auth.accessData ?? const <String, dynamic>{};
    final dashboard = reservation.dashboardData ?? const <String, dynamic>{};
    final user = auth.user;

    final commercialState = resolveCommercialAccessState(access);
    final statusLabel = _accountStatusLabel(access);
    final planLabel = _planLabel(access);
    final membershipCaption = _membershipCaption(access);
    final phone =
        user?.phone.isNotEmpty == true
            ? user!.phone
            : 'Pendiente por registrar';
    final company =
        user?.companyName.isNotEmpty == true
            ? user!.companyName
            : 'Cuenta privada';
    final displayName =
        auth.displayName.trim().isNotEmpty ? auth.displayName : 'Cliente';
    final email = user?.email ?? 'Sin correo';
    final initial =
        displayName.trim().isNotEmpty
            ? displayName.trim().characters.first.toUpperCase()
            : 'C';

    return ClientExperienceShell(
      title: 'Perfil',
      subtitle: 'Cuenta, expediente y preferencias.',
      showBackButton: widget.showBackButton,
      includeTopSafeArea: !widget.hasExternalTopBanner,
      child: Container(
        color: palette.background,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 132),
          children: [
            Text(
              'Perfil cliente',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: palette.textPrimary,
                height: 1,
                letterSpacing: -1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Expediente, membresía, seguridad y preferencias de viaje.',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            _AccountHeaderCard(
              initial: initial,
              name: displayName,
              email: email,
              status: statusLabel,
              membership: planLabel,
              membershipCaption: membershipCaption,
              onRefresh: _refreshProfile,
            ),
            const SizedBox(height: 12),
            _ProfileTabBar(
              activeTab: _activeTab,
              onSelect: (tab) => setState(() => _activeTab = tab),
            ),
            const SizedBox(height: 8),
            ..._tabContent(
              auth: auth,
              reservation: reservation,
              access: access,
              commercialState: commercialState,
              dashboard: dashboard,
              displayName: displayName,
              email: email,
              phone: phone,
              company: company,
              statusLabel: statusLabel,
              planLabel: planLabel,
            ),
            const SizedBox(height: 20),
            _ActionCard(onRefresh: _refreshProfile, onSignOut: auth.signOut),
          ],
        ),
      ),
    );
  }

  void _refreshProfile() {
    context.read<AuthProvider>().loadUserRole();
    context.read<ReservationProvider>().loadClientWorkspaceData(force: true);
  }

  List<Widget> _tabContent({
    required AuthProvider auth,
    required ReservationProvider reservation,
    required Map<String, dynamic> access,
    required CommercialAccessState commercialState,
    required Map<String, dynamic> dashboard,
    required String displayName,
    required String email,
    required String phone,
    required String company,
    required String statusLabel,
    required String planLabel,
  }) {
    final requests = reservation.flightRequests;
    final metrics = _nestedMap(dashboard['metrics'] ?? dashboard['summary']);

    switch (_activeTab) {
      case _ProfileTab.dashboard:
        return [
          _MetricWrap(
            metrics: [
              _MetricData(
                label: 'Solicitudes',
                value:
                    (metrics['solicitudes'] ??
                            metrics['requests'] ??
                            requests.length)
                        .toString(),
              ),
              _MetricData(
                label: 'Vuelos',
                value:
                    (metrics['vuelos'] ??
                            metrics['flights'] ??
                            metrics['completed_flights'] ??
                            0)
                        .toString(),
              ),
              _MetricData(
                label: 'Estado',
                value:
                    commercialState.hasPaidAccess || commercialState.canReserve
                        ? 'Activa'
                        : 'Pendiente',
              ),
              _MetricData(label: 'Membresía', value: planLabel),
            ],
          ),
          const SizedBox(height: 16),
          _MinimalProfileCard(
            title: 'Actividad reciente',
            items:
                requests.isEmpty
                    ? const [
                      _ProfileData(
                        label: 'Estado',
                        value: 'Aún no hay operaciones recientes',
                      ),
                    ]
                    : requests
                        .take(4)
                        .map(
                          (request) => _ProfileData(
                            label: _routeLabel(request),
                            value: _recentActivityValue(request),
                          ),
                        )
                        .toList(),
          ),
        ];

      case _ProfileTab.billing:
        return [
          _MinimalProfileCard(
            title: 'Pago',
            items: [
              _ProfileData(label: 'Empresa', value: company),
              _ProfileData(label: 'Correo fiscal', value: email),
              _ProfileData(
                label: 'Método',
                value: reservation.paymentMethod ?? 'Por definir',
              ),
              _ProfileData(
                label: 'Banco',
                value: reservation.bankName ?? 'Por definir',
              ),
            ],
          ),
        ];

      case _ProfileTab.security:
        return [
          _MinimalProfileCard(
            title: 'Seguridad',
            items: [
              _ProfileData(
                label: 'Sesión',
                value: auth.isAuthenticated ? 'Activa' : 'Inactiva',
              ),
              _ProfileData(label: 'Rol', value: auth.role.name),
              _ProfileData(
                label: 'Validación',
                value: _identityStatus(auth.userPayload),
              ),
              _ProfileData(
                label: 'Última actualización',
                value: _syncLabel(reservation.lastWorkspaceSyncAt),
              ),
            ],
          ),
        ];
    }
  }

  Map<String, dynamic> _nestedMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String _routeLabel(Map<String, dynamic> request) {
    final origin = request['origin']?.toString() ?? '';
    final destination = request['destination']?.toString() ?? '';
    if (origin.isEmpty && destination.isEmpty) return 'Solicitud';
    return '$origin → $destination';
  }

  String _recentActivityValue(Map<String, dynamic> request) {
    final stage = resolveClientWorkflowStage(request);
    switch (stage) {
      case 'contract_pending':
        return 'Contrato pendiente';
      case 'contract_signed':
        return 'Contrato firmado';
      case 'payment_pending':
        return 'Pago pendiente';
      case 'provider_accepted':
        return 'Respuesta proveedor';
      default:
        return clientWorkflowLabelForStage(stage);
    }
  }

  String _identityStatus(Map<String, dynamic>? payload) {
    final profile = _nestedMap(payload?['profile']);
    final verified =
        payload?['identity_verified'] ?? profile['identity_verified'];
    if (verified == true || verified == 1 || verified == '1') {
      return 'Verificada';
    }
    final value =
        (payload?['identity_verification_status'] ??
                payload?['identity_status'] ??
                profile['identity_verification_status'])
            ?.toString()
            .trim() ??
        '';
    return value.isEmpty ? 'Pendiente' : value;
  }

  String _syncLabel(DateTime? value) {
    if (value == null) return 'Sin sincronización';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  bool _hasMembership(Map<String, dynamic> access) {
    final commercialState = resolveCommercialAccessState(access);
    if (commercialState.hasPaidAccess || commercialState.canReserve) {
      return true;
    }

    final subscription = access['subscription'];
    if (subscription is Map) {
      final status = subscription['status']?.toString().trim().toLowerCase();
      if (status == 'active' || status == 'activo') return true;

      final rawDate =
          subscription['current_period_end'] ??
          subscription['expires_at'] ??
          subscription['renewal_date'];
      final parsed =
          rawDate == null ? null : DateTime.tryParse(rawDate.toString());
      if (parsed != null && parsed.isAfter(DateTime.now())) return true;
    }

    final membership = access['membership'];
    if (membership is Map) {
      final status = membership['status']?.toString().trim().toLowerCase();
      if (status == 'active' || status == 'activo') return true;
    }

    return false;
  }

  String _accountStatusLabel(Map<String, dynamic> access) {
    final commercialState = resolveCommercialAccessState(access);
    if (commercialState.hasPaidAccess ||
        commercialState.canReserve ||
        access['has_access'] == true ||
        _hasMembership(access)) {
      return 'Cuenta activa';
    }
    return 'Cuenta pendiente';
  }

  String _membershipCaption(Map<String, dynamic> access) {
    final commercialState = resolveCommercialAccessState(access);
    if (_hasMembership(access) && commercialState.expiresAtLabel.isNotEmpty) {
      return 'Activo hasta ${commercialState.expiresAtLabel}';
    }

    final subscription = access['subscription'];
    final rawDate =
        subscription is Map
            ? subscription['current_period_end'] ??
                subscription['expires_at'] ??
                subscription['renewal_date']
            : null;
    final parsed =
        rawDate == null ? null : DateTime.tryParse(rawDate.toString());
    if (_hasMembership(access) && parsed != null) {
      return 'Activo hasta ${DateFormat('dd MMM yyyy', 'es_MX').format(parsed)}';
    }
    if (_hasMembership(access)) return 'Membresía activa';
    return 'Sin membresía';
  }

  String _planLabel(Map<String, dynamic> access) {
    final subscription = access['subscription'];
    if (subscription is Map && subscription['plan_name'] != null) {
      return subscription['plan_name'].toString();
    }
    if (subscription is Map && subscription['plan'] != null) {
      return subscription['plan'].toString();
    }
    if (access['plan_name'] != null) return access['plan_name'].toString();
    if (_hasMembership(access)) return 'Membresía Executive';
    return 'Sin membresía';
  }
}

enum _ProfileTab { dashboard, billing, security }

extension _ProfileTabCopy on _ProfileTab {
  String get label {
    switch (this) {
      case _ProfileTab.dashboard:
        return 'Resumen';

      case _ProfileTab.billing:
        return 'Pago';

      case _ProfileTab.security:
        return 'Seguridad';
    }
  }
}

class _ProfileTabBar extends StatelessWidget {
  const _ProfileTabBar({required this.activeTab, required this.onSelect});

  final _ProfileTab activeTab;
  final ValueChanged<_ProfileTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            _ProfileTab.values.map((tab) {
              final active = tab == activeTab;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onSelect(tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: active ? palette.surfaceSoft : palette.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: active ? palette.accentBorder : palette.border,
                      ),
                    ),
                    child: Text(
                      tab.label,
                      style: TextStyle(
                        color: active ? palette.accent : palette.textSecondary,
                        fontWeight: FontWeight.w900,
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

class _MetricWrap extends StatelessWidget {
  const _MetricWrap({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return GridView.builder(
      itemCount: metrics.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 96,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: palette.headerGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: palette.accentBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                metric.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.heroTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                metric.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.heroTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({required this.label, required this.value});

  final String label;
  final String value;
}

class _AccountHeaderCard extends StatelessWidget {
  const _AccountHeaderCard({
    required this.initial,
    required this.name,
    required this.email,
    required this.status,
    required this.membership,
    required this.membershipCaption,
    required this.onRefresh,
  });

  final String initial;
  final String name;
  final String email;
  final String status;
  final String membership;
  final String membershipCaption;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette.headerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: palette.accentBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: palette.accentGradient),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: palette.textOnAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: palette.heroTextPrimary,
                        fontSize: 24,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      style: TextStyle(
                        color: palette.heroTextSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: onRefresh,
                borderRadius: BorderRadius.circular(999),
                child: Ink(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color:
                        context.isDarkMode
                            ? palette.surface
                            : Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.border),
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: palette.accent,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _HeaderInfoPill(
                  icon: Icons.verified_rounded,
                  label: 'Estado de cuenta',
                  value: status,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeaderInfoPill(
                  icon: Icons.workspace_premium_rounded,
                  label: 'Membresía',
                  value: membership,
                  subtitle: membershipCaption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderInfoPill extends StatelessWidget {
  const _HeaderInfoPill({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: palette.accent, size: 18),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MinimalProfileCard extends StatelessWidget {
  const _MinimalProfileCard({required this.title, required this.items});

  final String title;
  final List<_ProfileData> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: palette.accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(items.length, (index) {
            final item = items[index];
            final isLast = index == items.length - 1;
            return _ProfileRow(
              label: item.label,
              value: item.value,
              showDivider: !isLast,
            );
          }),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.onRefresh, required this.onSignOut});

  final VoidCallback onRefresh;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: onRefresh,
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: palette.textOnAccent,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Actualizar',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: onSignOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.textPrimary,
                minimumSize: const Size.fromHeight(52),
                side: BorderSide(color: palette.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Cerrar sesión',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final palette = context.clientPalette;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
        if (showDivider) ...[
          const SizedBox(height: 12),
          Divider(height: 1, color: palette.border),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ProfileData {
  const _ProfileData({required this.label, required this.value});

  final String label;
  final String value;
}
