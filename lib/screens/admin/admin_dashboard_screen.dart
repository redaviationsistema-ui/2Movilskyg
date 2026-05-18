import 'package:flutter/material.dart';

import '../../models/marketplace_models.dart';
import '../shared/widgets/role_ui_components.dart';
import 'views/admin_aircraft_screen.dart';
import 'views/admin_finance_screen.dart';
import 'views/admin_operators_screen.dart';
import 'views/admin_support_screen.dart';
import 'widgets/admin_cards.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  static const List<FeatureEntry> _featureViews = [
    FeatureEntry(
      title: 'Operadores',
      subtitle: 'Onboarding, checklist documental y aprobacion comercial.',
      icon: Icons.groups_rounded,
      screen: AdminOperatorsScreen(),
    ),
    FeatureEntry(
      title: 'Aeronaves',
      subtitle: 'Revision de matriculas, documentos y liberacion comercial.',
      icon: Icons.flight_class_rounded,
      screen: AdminAircraftScreen(),
    ),
    FeatureEntry(
      title: 'Finanzas',
      subtitle: 'Comisiones, payouts, refunds y conciliacion.',
      icon: Icons.account_balance_wallet_rounded,
      screen: AdminFinanceScreen(),
    ),
    FeatureEntry(
      title: 'Soporte',
      subtitle: 'Disputas, cancelaciones complejas y mesa de ayuda.',
      icon: Icons.support_agent_rounded,
      screen: AdminSupportScreen(),
    ),
  ];

  static const List<MarketplaceMetric> _metrics = [
    MarketplaceMetric(
      label: 'Operadores pendientes',
      value: '14',
      helper: 'Expedientes y documentos esperando validacion.',
    ),
    MarketplaceMetric(
      label: 'Disputas activas',
      value: '3',
      helper: 'Casos abiertos por cancelaciones, cambios o reembolsos.',
    ),
    MarketplaceMetric(
      label: 'Comision promedio',
      value: '11%',
      helper: 'Referencia de revenue por operacion procesada.',
    ),
  ];

  static const List<MarketplaceModule> _sections = [
    MarketplaceModule(
      title: 'Validar operadores',
      description:
          'Revision de identidad, certificados, seguros y cumplimiento.',
    ),
    MarketplaceModule(
      title: 'Aprobar aeronaves',
      description: 'Control documental, estatus y liberacion comercial.',
    ),
    MarketplaceModule(
      title: 'Controlar comisiones',
      description: 'Payout, fees, revenue share y conciliacion.',
    ),
    MarketplaceModule(
      title: 'Monitorear cancelaciones',
      description: 'Seguimiento de motivos, penalizaciones y reembolsos.',
    ),
    MarketplaceModule(
      title: 'Gestionar disputas',
      description: 'Resolucion de incidencias entre cliente y operador.',
    ),
    MarketplaceModule(
      title: 'Pagos y soporte',
      description: 'Cobros, devoluciones, creditos y mesa de ayuda.',
    ),
  ];

  static const List<RoadmapPhase> _roadmap = [
    RoadmapPhase(
      title: 'Fase 1 | MVP',
      description:
          'Busqueda, catalogo, solicitud, panel operador basico y admin basico.',
    ),
    RoadmapPhase(
      title: 'Fase 2 | Escala comercial',
      description:
          'Disponibilidad semiautomatica, pagos online, comparador y empty legs.',
    ),
    RoadmapPhase(
      title: 'Fase 3 | Inteligencia',
      description:
          'Pricing dinamico, scoring, contratos y programas corporativos.',
    ),
  ];

  static const List<String> _backendModules = [
    'autenticacion',
    'usuarios',
    'proveedores',
    'aeronaves',
    'disponibilidad',
    'cotizaciones',
    'reservas',
    'pagos',
    'cancelaciones',
    'notificaciones',
    'documentos',
    'analitica',
  ];

  static const List<String> _databaseTables = [
    'usuarios',
    'roles',
    'proveedores',
    'documentos de proveedor',
    'aeronaves',
    'disponibilidad de aeronaves',
    'solicitudes de cotizacion',
    'ofertas de cotizacion',
    'reservas',
    'pagos',
    'reembolsos',
    'cancelaciones',
    'estatus de vuelo',
    'reglas de precio',
    'tramos vacios',
    'resenas',
  ];

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'Sky Group | Administracion',
      subtitle:
          'Valida operadores, aprueba aeronaves, controla comisiones y gestiona soporte.',
      roleLabel: '🛡️ Cabina administracion',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SubscriptionStatusBanner(
            status: 'Control de demos activo',
            daysRemaining: 7,
          ),
          DashboardHero(
            eyebrow: 'Administracion',
            title: 'Control total del marketplace, demos y suscripciones',
            subtitle:
                'Administra clientes, proveedores, aeronaves, solicitudes, reservas, pagos y la conversion de demo gratuita a plan activo.',
            primaryLabel: 'Ver validaciones',
            primaryAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminOperatorsScreen()),
              );
            },
            secondaryLabel: 'Ver analitica',
            secondaryAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminFinanceScreen()),
              );
            },
          ),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Vistas creadas',
            subtitle:
                'Pantallas listas para gobierno, soporte y control del marketplace.',
          ),
          const SizedBox(height: 14),
          const FeatureNavigationGrid(items: _featureViews),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Vista administrativa',
            subtitle:
                'Panel de gobierno, operaciones y soporte del marketplace.',
          ),
          const SizedBox(height: 14),
          const MetricGrid(metrics: _metrics),
          const SizedBox(height: 24),
          const ModuleList(items: _sections),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Roadmap',
            subtitle:
                'Escalamiento recomendado para no construir todo al mismo tiempo.',
          ),
          const SizedBox(height: 14),
          const AdminRoadmapList(items: _roadmap),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Arquitectura sugerida',
            subtitle:
                'Modulos del sistema para separar bien el negocio y evitar cuellos de botella.',
          ),
          const SizedBox(height: 14),
          const ChipWrap(items: _backendModules),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Tablas clave',
            subtitle:
                'Base lista para cotizacion, booking, cancelaciones y estatus de vuelo.',
          ),
          const SizedBox(height: 14),
          const ChipWrap(items: _databaseTables),
        ],
      ),
    );
  }
}
