import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/marketplace_models.dart';
import '../../providers/reservation_provider.dart';
import '../shared/widgets/role_ui_components.dart';
import 'views/operator_fleet_screen.dart';
import 'views/operator_flights_screen.dart';
import 'views/operator_performance_screen.dart';
import 'views/operator_quotes_screen.dart';
import 'widgets/operator_cards.dart';

class OperatorDashboardScreen extends StatelessWidget {
  const OperatorDashboardScreen({super.key});

  static const List<FeatureEntry> _featureViews = [
    FeatureEntry(
      title: 'Flota',
      subtitle: 'Alta y control de aeronaves, fotos, documentos y amenities.',
      icon: Icons.airplanemode_active_rounded,
      screen: OperatorFleetScreen(),
    ),
    FeatureEntry(
      title: 'Cotizaciones',
      subtitle: 'Bandeja de solicitudes y constructor de ofertas para charter.',
      icon: Icons.request_quote_rounded,
      screen: OperatorQuotesScreen(),
    ),
    FeatureEntry(
      title: 'Vuelos',
      subtitle: 'Agenda operativa, tripulacion, restricciones e incidencias.',
      icon: Icons.event_available_rounded,
      screen: OperatorFlightsScreen(),
    ),
    FeatureEntry(
      title: 'Desempeno',
      subtitle: 'KPIs comerciales, scoring, ingresos y cancelaciones.',
      icon: Icons.query_stats_rounded,
      screen: OperatorPerformanceScreen(),
    ),
  ];

  static const List<MarketplaceMetric> _metrics = [
    MarketplaceMetric(
      label: 'Solicitudes activas',
      value: '18',
      helper: 'Solicitudes abiertas esperando respuesta del operador.',
    ),
    MarketplaceMetric(
      label: 'Tiempo respuesta',
      value: '12 min',
      helper: 'Indicador clave para rutas de ultima hora.',
    ),
    MarketplaceMetric(
      label: 'Aceptacion',
      value: '82%',
      helper: 'Mide capacidad comercial y confiabilidad operativa.',
    ),
  ];

  static const List<MarketplaceModule> _sections = [
    MarketplaceModule(
      title: 'Subir aviones',
      description:
          'Matricula, fabricante, modelo, categoria, base, fotos y amenities.',
    ),
    MarketplaceModule(
      title: 'Publicar disponibilidad',
      description:
          'Horarios, tiempos de respuesta, mantenimiento y estados operativos.',
    ),
    MarketplaceModule(
      title: 'Responder cotizaciones',
      description:
          'Solicitudes manuales con oferta, observaciones, restricciones y validez.',
    ),
    MarketplaceModule(
      title: 'Ajustar precios',
      description:
          'Tarifa por hora, minimo diario, reposicionamiento y gastos adicionales.',
    ),
    MarketplaceModule(
      title: 'Aceptar o rechazar vuelos',
      description:
          'Decision operativa segun slots, tripulacion y viabilidad real.',
    ),
    MarketplaceModule(
      title: 'Administrar operacion',
      description: 'Tripulacion, horarios, restricciones y cancelaciones.',
    ),
  ];

  static const List<OperatorRequest> _requests = [
    OperatorRequest(
      route: 'MTY -> TLC',
      aircraftCategory: 'Jet ligero',
      etaResponse: 'Responder en 15 min',
      status: 'Nueva',
      notes: 'Salida manana 08:00. Cliente corporativo.',
    ),
    OperatorRequest(
      route: 'MEX -> CUN',
      aircraftCategory: 'Super mediano',
      etaResponse: 'Oferta enviada',
      status: 'Activa',
      notes: 'Incluye catering, WiFi y traslado terrestre.',
    ),
    OperatorRequest(
      route: 'GDL -> LAX',
      aircraftCategory: 'Jet pesado',
      etaResponse: 'Bajo revision',
      status: 'Validacion',
      notes: 'Permisos, slots y documentacion internacional en proceso.',
    ),
  ];

  static const List<MarketplaceModule> _extraViews = [
    MarketplaceModule(
      title: 'Vista de dashboard',
      description:
          'KPIs de aceptacion, cancelaciones, ingresos y tiempos de respuesta.',
    ),
    MarketplaceModule(
      title: 'Vista de solicitudes',
      description:
          'Bandeja de solicitudes con filtros por estatus, categoria y aeropuerto.',
    ),
    MarketplaceModule(
      title: 'Vista de vuelos',
      description:
          'Confirmados, en curso, completados y cancelados con bitacora.',
    ),
    MarketplaceModule(
      title: 'Vista de desempeno',
      description:
          'Scoring, calificaciones y comparativo historico del operador.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReservationProvider>();
    final fleet = provider.aircraftFleet.take(6).toList();

    return RoleDashboardScaffold(
      title: 'Sky Group | Operador',
      subtitle:
          'Sube aviones, publica disponibilidad, responde cotizaciones y administra operacion.',
      roleLabel: '🛩️ Cabina operador',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SubscriptionStatusBanner(
            status: 'Demo proveedor activa',
            daysRemaining: 10,
          ),
          DashboardHero(
            eyebrow: 'Operador',
            title: 'Panel de proveedor para flota, disponibilidad y ofertas',
            subtitle:
                'Publica aeronaves, administra calendario operativo, bloquea disponibilidad y responde cotizaciones dentro de un producto SaaS de paga.',
            primaryLabel: 'Ver flota',
            primaryAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OperatorFleetScreen()),
              );
            },
            secondaryLabel: 'Ver solicitudes',
            secondaryAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OperatorQuotesScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Vistas creadas',
            subtitle:
                'Pantallas listas para la operacion diaria del proveedor.',
          ),
          const SizedBox(height: 14),
          const FeatureNavigationGrid(items: _featureViews),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Cabina del operador',
            subtitle:
                'Vistas necesarias para publicar, cotizar, aprobar y operar vuelos.',
          ),
          const SizedBox(height: 14),
          const MetricGrid(metrics: _metrics),
          const SizedBox(height: 24),
          const ModuleList(items: _sections),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Solicitudes actuales',
            subtitle:
                'Solicitudes que muestran el comportamiento esperado del marketplace.',
          ),
          const SizedBox(height: 14),
          const OperatorRequestList(requests: _requests),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Mas vistas',
            subtitle:
                'Pantallas que convierten el portal en una mini herramienta operativa.',
          ),
          const SizedBox(height: 14),
          const ModuleList(items: _extraViews),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Flota sincronizada',
            subtitle:
                'Datos tomados desde la flota real cargada en el sistema.',
          ),
          const SizedBox(height: 14),
          if (fleet.isEmpty)
            const EmptyStateCard(
              message:
                  'La flota todavia no esta disponible para este operador.',
            )
          else
            OperatorFleetList(aircraft: fleet),
        ],
      ),
    );
  }
}
