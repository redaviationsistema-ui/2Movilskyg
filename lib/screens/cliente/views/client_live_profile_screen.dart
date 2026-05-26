import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../widgets/client_experience_widgets.dart';

const Color kBg = Color(0xFFF7F7F7);
const Color kWhite = Colors.white;
const Color kBlack = Color(0xFF050505);
const Color kText = Color(0xFF111111);
const Color kMuted = Color(0xFF666666);
const Color kBorder = Color(0xFFE6E6E6);
const Color kSoft = Color(0xFFF2F2F2);

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

    final displayName =
        auth.displayName.trim().isNotEmpty ? auth.displayName : 'Cliente';

    final email = user?.email ?? 'Sin correo';

    final initial =
        displayName.trim().isNotEmpty
            ? displayName.trim().characters.first.toUpperCase()
            : 'C';

    return ClientExperienceShell(
      title: 'Perfil',
      subtitle: 'Cuenta y acceso.',
      showBackButton: showBackButton,
      trailing: StatusBadge(
        label: statusLabel == 'Activo' ? 'Activo' : 'Cliente',
        color: kBlack,
      ),
      child: Container(
        color: kBg,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const Text(
              'Perfil',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: kBlack,
                height: 1,
                letterSpacing: -1.1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Datos principales de tu cuenta.',
              style: TextStyle(
                color: kMuted,
                fontSize: 16,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),

            _AccountHeaderCard(
              initial: initial,
              name: displayName,
              email: email,
              status: statusLabel,
              onRefresh: () => context.read<AuthProvider>().loadUserRole(),
            ),

            const SizedBox(height: 16),

            _MinimalProfileCard(
              title: 'Cuenta',
              items: [
                _ProfileData(label: 'Nombre', value: user?.name ?? 'Pendiente'),
                _ProfileData(label: 'Empresa', value: company),
                _ProfileData(label: 'Correo', value: email),
                _ProfileData(label: 'Teléfono', value: phone),
              ],
            ),

            const SizedBox(height: 16),

            _MinimalProfileCard(
              title: 'Acceso',
              items: [
                _ProfileData(label: 'Estado', value: statusLabel),
                _ProfileData(label: 'Plan', value: _planLabel(access)),
                _ProfileData(
                  label: 'Reservar',
                  value: access['can_book'] == true ? 'Disponible' : 'Pendiente',
                ),
                _ProfileData(
                  label: 'Solicitudes',
                  value:
                      access['can_request_flights'] == true
                          ? 'Disponibles'
                          : 'Pendientes',
                ),
              ],
            ),

            const SizedBox(height: 16),

            _ActionCard(
              onRefresh: () => context.read<AuthProvider>().loadUserRole(),
              onSignOut: () => context.read<AuthProvider>().signOut(),
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(28),
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
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: kBlack,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: kWhite,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kBlack,
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 6),
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
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? kBlack : kSoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isActive ? kBlack : kBorder,
                    ),
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: kSoft,
                shape: BoxShape.circle,
                border: Border.all(color: kBorder),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: kBlack,
                size: 21,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MinimalProfileCard extends StatelessWidget {
  const _MinimalProfileCard({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_ProfileData> items;

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
  const _ActionCard({
    required this.onRefresh,
    required this.onSignOut,
  });

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
  const _ProfileData({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}