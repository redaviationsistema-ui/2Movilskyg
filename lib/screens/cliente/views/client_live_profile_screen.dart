import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../widgets/client_experience_widgets.dart';

class ClientLiveProfileScreen extends StatelessWidget {
  const ClientLiveProfileScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final access = auth.accessData ?? const <String, dynamic>{};
    final user = auth.user;

    return ClientExperienceShell(
      title: 'Perfil',
      subtitle: 'Informacion real de cuenta y acceso cargada desde auth/me.',
      showBackButton: showBackButton,
      trailing: StatusBadge(
        label: auth.role.name,
        color: const Color(0xFF143955),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          ClientHeroCard(
            badge: auth.displayName,
            title: 'Tu cuenta opera sobre datos reales del backend',
            subtitle:
                'Este perfil usa la informacion autenticada de la sesion para mostrar cuenta, acceso y datos de contacto sin contenido demo.',
            metrics: [
              ClientHeroMetric(
                label: 'Correo',
                value: user?.email ?? 'Sin correo',
              ),
              ClientHeroMetric(
                label: 'Telefono',
                value:
                    user?.phone.isNotEmpty == true ? user!.phone : 'Pendiente',
              ),
              ClientHeroMetric(label: 'Acceso', value: _accessLabel(access)),
            ],
            primaryLabel: 'Cerrar sesion',
            primaryAction: () => context.read<AuthProvider>().signOut(),
            secondaryLabel: 'Recargar perfil',
            secondaryAction: () => context.read<AuthProvider>().loadUserRole(),
          ),
          const SizedBox(height: 24),
          const ClientSectionTitle(
            title: 'Datos de cuenta',
            subtitle: 'Informacion entregada por tu backend autenticado.',
          ),
          const SizedBox(height: 14),
          GlassInfoCard(
            child: Column(
              children: [
                _ProfileRow(label: 'Nombre', value: user?.name ?? 'Pendiente'),
                const SizedBox(height: 12),
                _ProfileRow(
                  label: 'Empresa',
                  value:
                      user?.companyName.isNotEmpty == true
                          ? user!.companyName
                          : 'Sin empresa',
                ),
                const SizedBox(height: 12),
                _ProfileRow(label: 'Correo', value: user?.email ?? 'Pendiente'),
                const SizedBox(height: 12),
                _ProfileRow(
                  label: 'Telefono',
                  value:
                      user?.phone.isNotEmpty == true
                          ? user!.phone
                          : 'Pendiente',
                ),
                const SizedBox(height: 12),
                _ProfileRow(label: 'Rol', value: auth.role.name),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const ClientSectionTitle(
            title: 'Acceso comercial',
            subtitle: 'Resumen real del estado de demo o suscripcion.',
          ),
          const SizedBox(height: 14),
          GlassInfoCard(
            child: Column(
              children: [
                _ProfileRow(label: 'Estado', value: _accessLabel(access)),
                const SizedBox(height: 12),
                _ProfileRow(label: 'Plan', value: _planLabel(access)),
                const SizedBox(height: 12),
                _ProfileRow(
                  label: 'Reservar',
                  value: access['can_book']?.toString() ?? 'N/D',
                ),
                const SizedBox(height: 12),
                _ProfileRow(
                  label: 'Solicitudes',
                  value: access['can_request_flights']?.toString() ?? 'N/D',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _accessLabel(Map<String, dynamic> access) {
    final subscription = access['subscription'];
    if (subscription is Map && subscription['status'] != null) {
      return subscription['status'].toString();
    }
    if (access['subscription_status'] != null) {
      return access['subscription_status'].toString();
    }
    if (access['has_access'] == true) {
      return 'Activo';
    }
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
    if (access['plan_name'] != null) {
      return access['plan_name'].toString();
    }
    return 'Sin plan';
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF607080),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF10253A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
