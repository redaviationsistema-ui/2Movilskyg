import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/proveedor_reservaciones.dart';
import 'tema_cliente.dart';
import '../reservation/pantalla_reservacion.dart';
import '../shared/widgets/componentes_ui_rol.dart';
import 'views/pantalla_concierge_cliente.dart';
import 'views/pantalla_historial_cliente.dart';
import 'views/pantalla_resultados_cliente.dart';
import 'views/pantalla_busqueda_cliente.dart';
import 'views/pantalla_seguimiento_cliente.dart';
import 'widgets/tarjetas_flota_cliente.dart';

const Color kBg = ClientThemeColors.bg;
const Color kWhite = ClientThemeColors.surface;
const Color kBlack = ClientThemeColors.brandNight;
const Color kText = ClientThemeColors.text;
const Color kMuted = ClientThemeColors.muted;
const Color kBorder = ClientThemeColors.border;
const Color kSoft = ClientThemeColors.softSurface;

class ClientDashboardScreen extends StatelessWidget {
  const ClientDashboardScreen({super.key});

  static const RoleDashboardPalette _clientDashboardPalette =
      RoleDashboardPalette(
        backgroundGradient: ClientThemeColors.appGradient,
        contentBackgroundColor: ClientThemeColors.bg,
        headerGradient: ClientThemeColors.headerGradient,
        headerBorderColor: ClientThemeColors.accentBorder,
        headerBadgeGradient: ClientThemeColors.accentGradient,
        headerBadgeIconColor: ClientThemeColors.brandNavy,
        roleLabelColor: Colors.white,
        menuIconColor: Colors.white,
      );

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
                        backgroundColor: ClientThemeColors.accent,
                        foregroundColor: ClientThemeColors.textOnAccent,
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
      palette: _clientDashboardPalette,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: ClientThemeColors.appGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
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

            const SizedBox(height: 14),

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
  const _MinimalHero({required this.onReserve, required this.onRequestQuote});

  static const Color _heroNight = Color(0xFF052A46);
  static const Color _heroBlue = Color(0xFF0756B3);
  static const Color _heroCta = Color(0xFF075FE4);
  static const Color _heroGreen = Color(0xFF159A62);
  static const Color _heroGreenSoft = Color(0xFFEAF8F1);
  static const Color _heroOrange = Color(0xFFFF8500);
  static const Color _heroOrangeSoft = Color(0xFFFFF2E5);
  static const Color _heroTeal = Color(0xFF00A7A7);
  static const Color _heroTealSoft = Color(0xFFE8F9F9);
  static const Color _heroViolet = Color(0xFF7C3AED);
  static const Color _heroVioletSoft = Color(0xFFF2EBFF);
  static const Color _heroBlueSoft = Color(0xFFEAF4FF);
  static const Color _heroCanvas = Color(0xFFF4F7FA);
  static const Color _heroText = Color(0xFF082A45);
  static const Color _heroMuted = Color(0xFF64748B);
  static const Color _heroLine = Color(0xFFDCE5EE);

  final VoidCallback onReserve;
  final VoidCallback onRequestQuote;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_heroNight, _heroBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeroStatusBadge(),
                      SizedBox(height: 12),
                      Text(
                        'MMGL → MMTO',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.9,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'HAWKER 800XPI',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFD8E6F4),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.flight_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: _heroCanvas,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columnWidth = (constraints.maxWidth - 1) / 2;
                return Wrap(
                  children: [
                    SizedBox(
                      width: columnWidth,
                      child: _HeroInfoCell(
                        icon: Icons.calendar_month_rounded,
                        label: 'Fecha',
                        value: '18 ago 2026',
                        color: const Color(0xFF1976D2),
                        softColor: _heroBlueSoft,
                        showRightBorder: true,
                        showBottomBorder: true,
                      ),
                    ),
                    SizedBox(
                      width: columnWidth,
                      child: _HeroInfoCell(
                        icon: Icons.schedule_rounded,
                        label: 'Reporte',
                        value: '02:00',
                        color: _heroOrange,
                        softColor: _heroOrangeSoft,
                        showBottomBorder: true,
                      ),
                    ),
                    SizedBox(
                      width: columnWidth,
                      child: _HeroInfoCell(
                        icon: Icons.groups_rounded,
                        label: 'Pasajeros',
                        value: '1 pax',
                        color: _heroViolet,
                        softColor: _heroVioletSoft,
                        showRightBorder: true,
                        showBottomBorder: true,
                      ),
                    ),
                    SizedBox(
                      width: columnWidth,
                      child: _HeroInfoCell(
                        icon: Icons.flight_takeoff_rounded,
                        label: 'Salida',
                        value: 'MMGL',
                        color: _heroTeal,
                        softColor: _heroTealSoft,
                        showBottomBorder: true,
                      ),
                    ),
                    SizedBox(
                      width: columnWidth,
                      child: _HeroInfoCell(
                        icon: Icons.flight_land_rounded,
                        label: 'Llegada',
                        value: 'MMTO',
                        color: _heroTeal,
                        softColor: _heroTealSoft,
                        showRightBorder: true,
                      ),
                    ),
                    SizedBox(
                      width: columnWidth,
                      child: _HeroInfoCell(
                        icon: Icons.verified_rounded,
                        label: 'Estado',
                        value: 'Confirmado',
                        color: _heroGreen,
                        softColor: _heroGreenSoft,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onReserve,
                    style: FilledButton.styleFrom(
                      backgroundColor: _heroCta,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text(
                      'Continuar con mi vuelo',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onRequestQuote,
                    style: TextButton.styleFrom(
                      foregroundColor: _heroBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Ver detalles',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
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

class _HeroStatusBadge extends StatelessWidget {
  const _HeroStatusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _MinimalHero._heroGreenSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 14, color: _MinimalHero._heroGreen),
          SizedBox(width: 6),
          Text(
            'Confirmado',
            style: TextStyle(
              color: _MinimalHero._heroGreen,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroInfoCell extends StatelessWidget {
  const _HeroInfoCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.softColor,
    this.showRightBorder = false,
    this.showBottomBorder = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color softColor;
  final bool showRightBorder;
  final bool showBottomBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        border: Border(
          right:
              showRightBorder
                  ? const BorderSide(color: _MinimalHero._heroLine)
                  : BorderSide.none,
          bottom:
              showBottomBorder
                  ? const BorderSide(color: _MinimalHero._heroLine)
                  : BorderSide.none,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: softColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _MinimalHero._heroMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _MinimalHero._heroText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
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

class _MinimalSectionTitle extends StatelessWidget {
  const _MinimalSectionTitle({required this.title, required this.subtitle});

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
                  color: Colors.white,
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
          color: ClientThemeColors.darkCard,
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
                color: ClientThemeColors.darkCardSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ClientThemeColors.accentBorder),
              ),
              child: Icon(icon, color: ClientThemeColors.accent, size: 20),
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
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
          gradient: const LinearGradient(
            colors: ClientThemeColors.headerGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
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
            Icon(Icons.route_rounded, color: kWhite, size: 26),
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
                      color: kMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: kWhite),
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
        color: ClientThemeColors.darkCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
      ),
    );
  }
}
