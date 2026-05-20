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
    final statusLabel = _accessLabel(access);
    final phone =
        user?.phone.isNotEmpty == true
            ? user!.phone
            : 'Pendiente por registrar';
    final company =
        user?.companyName.isNotEmpty == true
            ? user!.companyName
            : 'Cuenta privada';

    return ClientExperienceShell(
      title: 'Cuenta',
      subtitle:
          'Consulta tu informacion de contacto, acceso y preferencias de vuelo.',
      showBackButton: showBackButton,
      trailing: StatusBadge(
        label: statusLabel == 'Activo' ? 'Cliente activo' : 'Cliente',
        color:
            statusLabel == 'Activo'
                ? const Color(0xFF2D6A4F)
                : const Color(0xFF9A6F28),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Text(
            'Perfil de cliente',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color(0xFF10253A),
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Consulta tu informacion de contacto, acceso y preferencias de vuelo.',
            style: TextStyle(
              color: Color(0xFF607080),
              fontSize: 16,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          _ProfileHeroCard(
            badge: statusLabel == 'Activo' ? 'Cuenta activa' : 'Cliente',
            title: auth.displayName,
            email: user?.email ?? 'Sin correo',
            phone: phone,
            primaryLabel: 'Actualizar datos',
            primaryAction: () => context.read<AuthProvider>().loadUserRole(),
            secondaryLabel: 'Cerrar sesion',
            secondaryAction: () => context.read<AuthProvider>().signOut(),
          ),
          const SizedBox(height: 24),
          const ClientSectionTitle(
            title: 'Datos de cuenta',
            subtitle: 'Informacion registrada en tu perfil.',
          ),
          const SizedBox(height: 14),
          GlassInfoCard(
            child: Column(
              children: [
                _ProfileItem(label: 'Nombre', value: user?.name ?? 'Pendiente'),
                const SizedBox(height: 12),
                _ProfileItem(label: 'Empresa', value: company),
                const SizedBox(height: 12),
                _ProfileItem(
                  label: 'Correo',
                  value: user?.email ?? 'Pendiente',
                ),
                const SizedBox(height: 12),
                _ProfileItem(label: 'Telefono', value: phone),
                const SizedBox(height: 12),
                _ProfileItem(label: 'Estado', value: statusLabel),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const ClientSectionTitle(
            title: 'Acceso comercial',
            subtitle: 'Datos asociados a tu cuenta privada.',
          ),
          const SizedBox(height: 14),
          GlassInfoCard(
            child: Column(
              children: [
                _ProfileItem(label: 'Estado', value: statusLabel),
                const SizedBox(height: 12),
                _ProfileItem(label: 'Plan', value: _planLabel(access)),
                const SizedBox(height: 12),
                _ProfileItem(
                  label: 'Reservar',
                  value:
                      access['can_book'] == true ? 'Disponible' : 'Pendiente',
                ),
                const SizedBox(height: 12),
                _ProfileItem(
                  label: 'Solicitudes',
                  value:
                      access['can_request_flights'] == true
                          ? 'Disponibles'
                          : 'Pendientes',
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
      final value = subscription['status'].toString().trim();
      return value.isEmpty ? 'Pendiente' : value;
    }
    if (access['subscription_status'] != null) {
      final value = access['subscription_status'].toString().trim();
      return value.isEmpty ? 'Pendiente' : value;
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

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.badge,
    required this.title,
    required this.email,
    required this.phone,
    required this.primaryLabel,
    required this.primaryAction,
    required this.secondaryLabel,
    required this.secondaryAction,
  });

  final String badge;
  final String title;
  final String email;
  final String phone;
  final String primaryLabel;
  final VoidCallback primaryAction;
  final String secondaryLabel;
  final VoidCallback secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF071827), Color(0xFF103650)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E071827),
            blurRadius: 60,
            offset: Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.02,
            ),
          ),
          const SizedBox(height: 12),
          _HeroDataPill(label: 'Correo', value: email),
          const SizedBox(height: 10),
          _HeroDataPill(label: 'Telefono', value: phone),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: primaryAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE8C36A),
                    foregroundColor: const Color(0xFF111111),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(primaryLabel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: secondaryAction,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.20),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(secondaryLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroDataPill extends StatelessWidget {
  const _HeroDataPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  const _ProfileItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEADFCE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D141414),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF607080),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF10253A),
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
