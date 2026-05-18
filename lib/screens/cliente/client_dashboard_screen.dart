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

class ClientDashboardScreen extends StatelessWidget {
  const ClientDashboardScreen({super.key});

  static const List<FeatureEntry> _featureViews = [
    FeatureEntry(
      title: 'Busqueda',
      subtitle: 'Reserva inmediata con accesos rapidos y tono premium.',
      icon: Icons.search_rounded,
      screen: ClientSearchScreen(),
    ),
    FeatureEntry(
      title: 'Resultados',
      subtitle: 'Comparador premium con score, tarifa y detalle util.',
      icon: Icons.view_agenda_rounded,
      screen: ClientResultsScreen(),
    ),
    FeatureEntry(
      title: 'Seguimiento',
      subtitle:
          'Seguimiento ejecutivo con linea de tiempo, sincronizacion y soporte.',
      icon: Icons.route_rounded,
      screen: ClientTrackingScreen(),
    ),
    FeatureEntry(
      title: 'Historial',
      subtitle: 'Mis vuelos, reagenda y politicas para recompra.',
      icon: Icons.history_rounded,
      screen: ClientHistoryScreen(),
    ),
    FeatureEntry(
      title: 'Asistente VIP',
      subtitle: 'Asistencia premium para amenidades, traslados y urgencias.',
      icon: Icons.support_agent_rounded,
      screen: ClientConciergeScreen(),
    ),
  ];

  static const List<MarketplaceMetric> _metrics = [
    MarketplaceMetric(
      label: 'Reserva',
      value: 'Directa + asistida',
      helper: 'Combina flujo de app con respaldo de concierge y operaciones.',
    ),
    MarketplaceMetric(
      label: 'Disponibilidad',
      value: 'Hoy / manana',
      helper:
          'Estados claros para mover rapido al cliente sin falsas promesas.',
    ),
    MarketplaceMetric(
      label: 'Perfil',
      value: 'Profesional',
      helper: 'Lenguaje premium, visual sobrio y menos texto estatico.',
    ),
  ];

  static const List<MarketplaceModule> _flows = [
    MarketplaceModule(
      title: 'Descubrir la mejor ruta',
      description:
          'Origen, destino, urgencia, pasajeros y experiencia requerida.',
    ),
    MarketplaceModule(
      title: 'Recibir opciones recomendadas',
      description: 'Tarjetas con tarifa, velocidad, base y accion inmediata.',
    ),
    MarketplaceModule(
      title: 'Abrir detalle ejecutivo',
      description: 'Snapshot de aeronave, razon comercial y servicio esperado.',
    ),
    MarketplaceModule(
      title: 'Reservar con soporte',
      description:
          'Flujo directo con respaldo humano cuando el caso lo requiere.',
    ),
    MarketplaceModule(
      title: 'Seguir el vuelo',
      description: 'Timeline claro con acceso FBO, tripulacion y concierge.',
    ),
  ];

  static const List<MarketplaceModule> _extraViews = [
    MarketplaceModule(
      title: 'Vista de reserva inmediata',
      description:
          'Home con CTA fuertes, accesos rapidos y tono de movilidad premium.',
    ),
    MarketplaceModule(
      title: 'Vista de opciones',
      description:
          'Comparador con tarjetas vivas, score premium y propuestas claras.',
    ),
    MarketplaceModule(
      title: 'Vista de detalle',
      description:
          'Ficha ejecutiva con snapshot operativo y argumentos comerciales.',
    ),
    MarketplaceModule(
      title: 'Vista de concierge',
      description:
          'Chat premium con soporte humano, compliance y servicios extra.',
    ),
  ];

  static const List<CancellationRule> _rules = [
    CancellationRule(
      window: 'Antes de confirmar',
      penalty: 'Sin cargo',
      action:
          'El cliente puede editar o cancelar la solicitud sin penalizacion.',
    ),
    CancellationRule(
      window: 'Mas de 72 horas',
      penalty: 'Cargo bajo',
      action:
          'Puede aplicar reembolso completo o credito futuro segun proveedor.',
    ),
    CancellationRule(
      window: '72 a 24 horas',
      penalty: 'Cargo parcial',
      action:
          'Se muestra monto retenido, motivo y posibilidad de reprogramacion.',
    ),
    CancellationRule(
      window: 'Menos de 24 horas',
      penalty: 'Cargo alto',
      action:
          'Se aplica politica del operador y se conserva evidencia del caso.',
    ),
  ];

  void _openRfqSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (_) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Solicitud de cotizacion',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'Ideal para jets pesados, rutas internacionales, VIP o salida de ultima hora.',
                ),
                SizedBox(height: 10),
                Text(
                  'La app envia la solicitud a operadores y concentra propuestas en una vista comparativa.',
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReservationProvider>();
    final fleet = provider.aircraftFleet.take(4).toList();

    return RoleDashboardScaffold(
      title: 'Sky Group | Cliente',
      subtitle:
          'Busca, compara y reserva una aeronave con una experiencia mas viva y ejecutiva.',
      roleLabel: 'Cabina cliente',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SyncStatusBanner(),
          const SubscriptionStatusBanner(),
          DashboardHero(
            eyebrow: 'Cliente',
            title: 'Marketplace premium de vuelos privados bajo demanda',
            subtitle:
                'Busca origen, destino, fecha, hora y pasajeros; compara aeronaves disponibles y convierte la demo en membresia cuando estes listo para reservar.',
            primaryLabel: 'Reservar ahora',
            primaryAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReservationScreen()),
              );
            },
            secondaryLabel: 'Solicitar cotizacion',
            secondaryAction: () => _openRfqSheet(context),
          ),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Vistas creadas',
            subtitle:
                'Pantallas listas para navegar desde la cabina del cliente.',
          ),
          const SizedBox(height: 14),
          const FeatureNavigationGrid(items: _featureViews),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Direccion visual',
            subtitle:
                'Una experiencia tipo Uber ejecutivo: rapida, guiada y profesional.',
          ),
          const SizedBox(height: 14),
          const MetricGrid(metrics: _metrics),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Flujo principal',
            subtitle:
                'El producto cliente ahora se organiza como journey comercial y operativo.',
          ),
          const SizedBox(height: 14),
          const ModuleList(items: _flows),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Mas vistas',
            subtitle:
                'La cabina ya contempla discovery, comparacion, detalle y concierge.',
          ),
          const SizedBox(height: 14),
          const ModuleList(items: _extraViews),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Aeronaves disponibles',
            subtitle:
                'Listado dinamico usando la flota sincronizada del sistema.',
          ),
          const SizedBox(height: 14),
          if (fleet.isEmpty)
            const EmptyStateCard(
              message:
                  'Todavia no hay aeronaves disponibles para mostrar en esta cuenta.',
            )
          else
            ClientFleetSection(aircraft: fleet),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Cancelaciones',
            subtitle:
                'Politicas presentadas con claridad para evitar friccion y disputas.',
          ),
          const SizedBox(height: 14),
          const ClientCancellationSection(rules: _rules),
        ],
      ),
    );
  }
}
