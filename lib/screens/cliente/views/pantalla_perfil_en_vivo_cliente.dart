import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  const ClientLiveProfileScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

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

    final statusLabel = _accessLabel(access);
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
      trailing: StatusBadge(
        label: statusLabel == 'Activo' ? 'Activo' : 'Cliente',
        color: kBlack,
      ),
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
              'Expediente, membresia, seguridad y preferencias de viaje.',
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
              status: statusLabel,
              plan: _planLabel(access),
              hasAccess: access['has_access'] == true,
            ),
            const SizedBox(height: 12),
            _ProfileTabBar(
              activeTab: _activeTab,
              onSelect: (tab) => setState(() => _activeTab = tab),
            ),
            const SizedBox(height: 12),
            ..._tabContent(
              auth: auth,
              reservation: reservation,
              access: access,
              dashboard: dashboard,
              displayName: displayName,
              email: email,
              phone: phone,
              company: company,
              statusLabel: statusLabel,
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
    required Map<String, dynamic> dashboard,
    required String displayName,
    required String email,
    required String phone,
    required String company,
    required String statusLabel,
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
              _MetricData(label: 'Acceso', value: statusLabel),
              _MetricData(label: 'Plan', value: _planLabel(access)),
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
                        value: 'Aun no hay operaciones recientes',
                      ),
                    ]
                    : requests
                        .take(4)
                        .map(
                          (request) => _ProfileData(
                            label: _routeLabel(request),
                            value: _statusValue(request),
                          ),
                        )
                        .toList(),
          ),
        ];
      case _ProfileTab.travelers:
        return [
          _MinimalProfileCard(
            title: 'Viajeros frecuentes',
            items: [
              _ProfileData(label: 'Titular', value: displayName),
              _ProfileData(
                label: 'Pasajeros',
                value: '${reservation.passengers} por defecto',
              ),
              _ProfileData(
                label: 'Mascotas',
                value:
                    reservation.pets.trim().isEmpty
                        ? 'Sin preferencia registrada'
                        : reservation.pets,
              ),
              _ProfileData(
                label: 'Equipaje',
                value:
                    reservation.specialBaggage.trim().isEmpty
                        ? 'Sin requerimientos especiales'
                        : reservation.specialBaggage,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PreferenceEditorCard(reservation: reservation),
        ];
      case _ProfileTab.preferences:
        return [
          _MinimalProfileCard(
            title: 'Preferencias de vuelo',
            items: [
              _ProfileData(
                label: 'Paquete',
                value: reservation.selectedPriorityLabel,
              ),
              _ProfileData(
                label: 'Cabina',
                value:
                    reservation.preference.trim().isEmpty
                        ? 'Por definir'
                        : reservation.preference,
              ),
              _ProfileData(
                label: 'Concierge',
                value:
                    reservation.conciergeRequested
                        ? 'Solicitado'
                        : 'Disponible',
              ),
            ],
          ),
        ];
      case _ProfileTab.billing:
        return [
          _MinimalProfileCard(
            title: 'Billing',
            items: [
              _ProfileData(label: 'Empresa', value: company),
              _ProfileData(label: 'Correo fiscal', value: email),
              _ProfileData(
                label: 'Metodo',
                value: reservation.paymentMethod ?? 'Por definir',
              ),
              _ProfileData(
                label: 'Banco',
                value: reservation.bankName ?? 'Por definir',
              ),
            ],
          ),
        ];
      case _ProfileTab.documents:
        return [
          _MinimalProfileCard(
            title: 'Documentos',
            items: [
              _ProfileData(
                label: 'Identidad',
                value: _documentStatus(auth.userPayload),
              ),
              _ProfileData(label: 'Telefono', value: phone),
              _ProfileData(label: 'Correo', value: email),
              const _ProfileData(
                label: 'NDA / privacidad',
                value: 'Pendiente de validacion',
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
                label: 'Sesion',
                value: auth.isAuthenticated ? 'Activa' : 'Inactiva',
              ),
              _ProfileData(label: 'Rol', value: auth.role.name),
              _ProfileData(
                label: 'Validacion',
                value: _identityStatus(auth.userPayload),
              ),
              _ProfileData(
                label: 'Ultima sync',
                value: _syncLabel(reservation.lastWorkspaceSyncAt),
              ),
            ],
          ),
        ];
      case _ProfileTab.concierge:
        return [
          _MinimalProfileCard(
            title: 'Concierge',
            items: [
              const _ProfileData(label: 'Cobertura', value: '24/7'),
              const _ProfileData(
                label: 'Canal',
                value: 'App + seguimiento operativo',
              ),
              _ProfileData(
                label: 'Estado',
                value:
                    reservation.conciergeRequested
                        ? 'Activado en solicitud'
                        : 'Disponible',
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
    return '$origin - $destination';
  }

  String _statusValue(Map<String, dynamic> request) {
    return (request['workflow_status'] ??
            request['status'] ??
            request['payment_status'] ??
            'En revision')
        .toString();
  }

  String _documentStatus(Map<String, dynamic>? payload) {
    final profile = _nestedMap(payload?['profile']);
    final value =
        (payload?['document_status'] ??
                payload?['identity_verification_status'] ??
                profile['document_status'])
            ?.toString()
            .trim() ??
        '';
    return value.isEmpty ? 'Pendiente' : value;
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
    if (value == null) return 'Sin sincronizacion';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _accessLabel(Map<String, dynamic> access) {
    final subscription = access['subscription'];
    if (subscription is Map && subscription['status'] != null) {
      final value = subscription['status'].toString().trim();
      return value.isEmpty ? 'Pendiente' : value;
    }
    if (access['subscription_status'] != null) {
      final value = access['subscription_status'].toString().trim();
      return value.isEmpty ? 'Pendiente' : value;
    }
    if (access['has_access'] == true) return 'Activo';
    return 'Pendiente';
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
    return 'Sin plan';
  }
}

enum _ProfileTab {
  dashboard,
  travelers,
  preferences,
  billing,
  documents,
  security,
  concierge,
}

extension _ProfileTabCopy on _ProfileTab {
  String get label {
    switch (this) {
      case _ProfileTab.dashboard:
        return 'Resumen';
      case _ProfileTab.travelers:
        return 'Viajeros';
      case _ProfileTab.preferences:
        return 'Preferencias';
      case _ProfileTab.billing:
        return 'Pago';
      case _ProfileTab.documents:
        return 'Documentos';
      case _ProfileTab.security:
        return 'Seguridad';
      case _ProfileTab.concierge:
        return 'Concierge';
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
        color: kBlack,
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
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          metrics.map((metric) {
            return Container(
              width: 155,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
          }).toList(),
    );
  }
}

class _PreferenceEditorCard extends StatelessWidget {
  const _PreferenceEditorCard({required this.reservation});

  final ReservationProvider reservation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PREFERENCIAS RAPIDAS',
            style: TextStyle(
              color: kMuted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: reservation.conciergeRequested,
            onChanged: reservation.setConciergeRequested,
            title: const Text(
              'Concierge activo para nuevas solicitudes',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                ReservationProvider.priorityLabels.entries.map((entry) {
                  return ChoiceChip(
                    selected: reservation.selectedPriorityType == entry.key,
                    label: Text(entry.value),
                    onSelected:
                        (_) => reservation.setSelectedPriorityType(entry.key),
                  );
                }).toList(),
          ),
        ],
      ),
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
    final isActive = status.toLowerCase() == 'activo';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? kBlack : kSoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: isActive ? kBlack : kBorder),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: isActive ? kWhite : kBlack,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
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
                'Cerrar sesion',
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
