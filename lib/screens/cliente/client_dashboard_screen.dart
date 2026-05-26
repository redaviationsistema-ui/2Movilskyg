import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/marketplace_models.dart';
import '../../providers/reservation_provider.dart';
import '../reservation/reservation_screen.dart';
import '../shared/widgets/role_ui_components.dart';
import 'views/client_concierge_screen.dart';
import 'views/client_history_screen.dart';
import 'views/client_results_screen.dart';
import 'views/client_search_screen.dart';
import 'views/client_tracking_screen.dart';
import 'widgets/client_fleet_cards.dart';

const Color kBg = Color(0xFFF7F7F7);
const Color kWhite = Colors.white;
const Color kBlack = Color(0xFF050505);
const Color kText = Color(0xFF111111);
const Color kMuted = Color(0xFF666666);
const Color kBorder = Color(0xFFE6E6E6);
const Color kSoft = Color(0xFFF2F2F2);

class ClientDashboardScreen extends StatelessWidget {
  const ClientDashboardScreen({super.key});

  static const List<FeatureEntry> _quickViews = [
    FeatureEntry(
      title: 'Buscar',
      subtitle: 'Cotizar ruta',
      icon: Icons.search_rounded,
      screen: ClientSearchScreen(),
    ),
    FeatureEntry(
      title: 'Opciones',
      subtitle: 'Ver aeronaves',
      icon: Icons.view_agenda_rounded,
      screen: ClientResultsScreen(),
    ),
    FeatureEntry(
      title: 'Vuelos',
      subtitle: 'Mis reservas',
      icon: Icons.history_rounded,
      screen: ClientHistoryScreen(),
    ),
    FeatureEntry(
      title: 'Concierge',
      subtitle: 'Soporte VIP',
      icon: Icons.support_agent_rounded,
      screen: ClientConciergeScreen(),
    ),
  ];

  void _openRfqSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder:
          (_) => SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Solicitud privada',
                    style: TextStyle(
                      fontSize: 26,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: kBlack,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Para rutas internacionales, jets pesados, vuelos urgentes o solicitudes VIP.',
                    style: TextStyle(
                      color: kMuted,
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReservationScreen(),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: kBlack,
                        foregroundColor: kWhite,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Iniciar solicitud',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReservationProvider>();
    final fleet = provider.aircraftFleet.take(4).toList();

    return RoleDashboardScaffold(
      title: 'Sky Group',
      subtitle: 'Cliente',
      roleLabel: 'Cliente',
      body: Container(
        color: kBg,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const SyncStatusBanner(),
            const SizedBox(height: 12),
            const SubscriptionStatusBanner(),
            const SizedBox(height: 16),

            _MinimalHero(
              onReserve: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReservationScreen()),
                );
              },
              onRequestQuote: () => _openRfqSheet(context),
            ),

            const SizedBox(height: 22),

            const _MinimalSectionTitle(
              title: 'Accesos rápidos',
              subtitle: 'Lo esencial para operar tu vuelo.',
            ),
            const SizedBox(height: 12),
            const _QuickAccessGrid(items: _quickViews),

            const SizedBox(height: 22),

            const _MinimalSectionTitle(
              title: 'Aeronaves',
              subtitle: 'Opciones disponibles en tu cuenta.',
            ),
            const SizedBox(height: 12),
            if (fleet.isEmpty)
              const _MinimalEmptyCard(
                message: 'Todavía no hay aeronaves disponibles.',
              )
            else
              ClientFleetSection(aircraft: fleet),

            const SizedBox(height: 22),

            _TrackingCard(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClientTrackingScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MinimalHero extends StatelessWidget {
  const _MinimalHero({
    required this.onReserve,
    required this.onRequestQuote,
  });

  final VoidCallback onReserve;
  final VoidCallback onRequestQuote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 32,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PRIVATE AVIATION',
            style: TextStyle(
              color: kMuted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Reserva un jet privado\nen minutos.',
            style: TextStyle(
              color: kBlack,
              fontSize: 34,
              height: 0.98,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Busca ruta, compara opciones y continúa con soporte ejecutivo.',
            style: TextStyle(
              color: kMuted,
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onReserve,
                  style: FilledButton.styleFrom(
                    backgroundColor: kBlack,
                    foregroundColor: kWhite,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Reservar',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onRequestQuote,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kBlack,
                    minimumSize: const Size.fromHeight(54),
                    side: const BorderSide(color: kBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Cotizar',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MinimalSectionTitle extends StatelessWidget {
  const _MinimalSectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: kBlack,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: kMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid({required this.items});

  final List<FeatureEntry> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        final item = items[index];

        return _QuickAccessCard(
          title: item.title,
          subtitle: item.subtitle,
          icon: item.icon,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => item.screen),
            );
          },
        );
      },
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  const _QuickAccessCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kBlack,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: kWhite, size: 20),
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kBlack,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kBlack,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(
              Icons.route_rounded,
              color: kWhite,
              size: 26,
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seguimiento',
                    style: TextStyle(
                      color: kWhite,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Consulta el avance de tu reserva.',
                    style: TextStyle(
                      color: Color(0xFFBDBDBD),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: kWhite,
            ),
          ],
        ),
      ),
    );
  }
}

class _MinimalEmptyCard extends StatelessWidget {
  const _MinimalEmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: kText,
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
      ),
    );
  }
}