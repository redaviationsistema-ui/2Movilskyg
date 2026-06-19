import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/acceso_comercial_cliente.dart';
import '../../../core/client_workflow_status.dart';
import '../../../providers/proveedor_autenticacion.dart';
import '../../../providers/proveedor_reservaciones.dart';
import '../widgets/widgets_experiencia_cliente.dart';

const Color kBg = Color(0xFFF7F7F7);
const Color kWhite = Colors.white;
const Color kBlack = Color(0xFF050505);
const Color kText = Color(0xFF111111);
const Color kMuted = Color(0xFF666666);
const Color kBorder = Color(0xFFE6E6E6);
const Color kSoft = Color(0xFFF2F2F2);

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
    final auth = context.watch<AuthProvider>();
    final reservation = context.watch<ReservationProvider>();
    final access = auth.accessData ?? const <String, dynamic>{};
    final dashboard = reservation.dashboardData ?? const <String, dynamic>{};
    final user = auth.user;

    final commercialState = resolveCommercialAccessState(access);
    final hasMembership = _hasMembership(access);
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
        color: kBg,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            const Text(
              'Perfil cliente',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: kBlack,
                height: 1,
                letterSpacing: -1.1,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Expediente, membresía, seguridad y preferencias de viaje.',
              style: TextStyle(
                color: kMuted,
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
              onRefresh: _refreshProfile,
            ),
            const SizedBox(height: 12),
            _MembershipInlineCard(
              status: membershipCaption,
              plan: planLabel,
              hasAccess: hasMembership,
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
            const SizedBox(height: 16),
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
              _MetricData(label: 'Plan', value: planLabel),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            _ProfileTab.values.map((tab) {
              final active = tab == activeTab;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  selected: active,
                  label: Text(tab.label),
                  onSelected: (_) => onSelect(tab),
                  selectedColor: kBlack,
                  backgroundColor: kWhite,
                  side: const BorderSide(color: kBorder),
                  visualDensity: VisualDensity.compact,
                  labelStyle: TextStyle(
                    color: active ? kWhite : kText,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _MembershipInlineCard extends StatelessWidget {
  const _MembershipInlineCard({
    required this.status,
    required this.plan,
    required this.hasAccess,
  });

  final String status;
  final String plan;
  final bool hasAccess;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasAccess ? kBlack : const Color(0xFF2A241D),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(
            hasAccess
                ? Icons.verified_rounded
                : Icons.workspace_premium_rounded,
            color: kWhite,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan,
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: const TextStyle(
                    color: Color(0xFFD9D9D9),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricWrap extends StatelessWidget {
  const _MetricWrap({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: metrics.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 82,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F6F1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                metric.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kBlack,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                metric.label,
                style: const TextStyle(
                  color: kMuted,
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
    required this.onRefresh,
  });

  final String initial;
  final String name;
  final String email;
  final String status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: kBlack,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: kWhite,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kBlack,
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color:
                            status.toLowerCase().contains('activa')
                                ? const Color(0xFF1B8F4D)
                                : const Color(0xFFB0893B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      status,
                      style: const TextStyle(
                        color: kBlack,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onRefresh,
            borderRadius: BorderRadius.circular(999),
            child: Ink(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kSoft,
                shape: BoxShape.circle,
                border: Border.all(color: kBorder),
              ),
              child: const Icon(Icons.refresh_rounded, color: kBlack, size: 19),
            ),
          ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: kMuted,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: onRefresh,
              style: FilledButton.styleFrom(
                backgroundColor: kBlack,
                foregroundColor: kWhite,
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
                foregroundColor: kBlack,
                minimumSize: const Size.fromHeight(52),
                side: const BorderSide(color: kBorder),
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
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: const TextStyle(
                  color: kMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kBlack,
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
          const Divider(height: 1, color: kBorder),
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
