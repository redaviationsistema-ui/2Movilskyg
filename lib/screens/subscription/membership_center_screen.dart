import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/marketplace_models.dart';
import '../../models/workflow_models.dart';
import '../../providers/workflow_provider.dart';
import '../shared/widgets/role_ui_components.dart';
import '../shared/widgets/workflow_crud_sheet.dart';

enum MembershipAudience { client, provider, admin }

class MembershipCenterScreen extends StatelessWidget {
  const MembershipCenterScreen({super.key, required this.audience});

  final MembershipAudience audience;

  String get _title {
    switch (audience) {
      case MembershipAudience.client:
        return 'Suscripcion y pagos';
      case MembershipAudience.provider:
        return 'Planes de proveedor';
      case MembershipAudience.admin:
        return 'Suscripciones y demos';
    }
  }

  String get _subtitle {
    switch (audience) {
      case MembershipAudience.client:
        return 'Demo de 15 dias, upgrade y acceso premium para buscar, cotizar y reservar vuelos privados.';
      case MembershipAudience.provider:
        return 'Acceso SaaS para publicar flota, administrar disponibilidad y responder solicitudes comerciales.';
      case MembershipAudience.admin:
        return 'Control de demos activas, conversion a planes, pagos y mensajes de bloqueo por vencimiento.';
    }
  }

  String get _roleLabel {
    switch (audience) {
      case MembershipAudience.client:
        return 'Membresia cliente';
      case MembershipAudience.provider:
        return 'Membresia proveedor';
      case MembershipAudience.admin:
        return 'Control SaaS';
    }
  }

  List<MarketplaceMetric> get _metrics {
    switch (audience) {
      case MembershipAudience.client:
        return const [
          MarketplaceMetric(
            label: 'Demo activa',
            value: '15 dias',
            helper: 'Acceso de prueba con indicadores visibles antes del pago.',
          ),
          MarketplaceMetric(
            label: 'Conversion',
            value: 'Upgrade',
            helper:
                'CTA elegante para continuar con membresia al terminar la demo.',
          ),
          MarketplaceMetric(
            label: 'Acceso',
            value: 'Reservas',
            helper:
                'Busqueda, cotizacion, detalle de aeronave e historial premium.',
          ),
        ];
      case MembershipAudience.provider:
        return const [
          MarketplaceMetric(
            label: 'Publicacion',
            value: 'Flota',
            helper:
                'Aeronaves, fotos, tarifas, disponibilidad y solicitudes de cotizacion.',
          ),
          MarketplaceMetric(
            label: 'Demo operativa',
            value: '15 dias',
            helper: 'Prueba controlada antes de activar el plan comercial.',
          ),
          MarketplaceMetric(
            label: 'Upgrade',
            value: 'Pro',
            helper: 'Mas aeronaves, reportes y soporte de operacion.',
          ),
        ];
      case MembershipAudience.admin:
        return const [
          MarketplaceMetric(
            label: 'Demos activas',
            value: '42',
            helper: 'Usuarios dentro del periodo gratuito de 15 dias.',
          ),
          MarketplaceMetric(
            label: 'Por vencer',
            value: '9',
            helper: 'Cuentas que requieren mensaje de conversion.',
          ),
          MarketplaceMetric(
            label: 'Planes activos',
            value: '128',
            helper: 'Clientes y proveedores con suscripcion vigente.',
          ),
        ];
    }
  }

  List<MarketplaceModule> get _flow {
    switch (audience) {
      case MembershipAudience.client:
        return const [
          MarketplaceModule(
            title: 'Activar demo gratuita',
            description:
                'El cliente inicia con 15 dias para explorar busqueda, resultados y cotizaciones.',
          ),
          MarketplaceModule(
            title: 'Mostrar estado siempre visible',
            description:
                'Banners de demo activa, demo por vencer, plan activo o suscripcion requerida.',
          ),
          MarketplaceModule(
            title: 'Bloqueo al vencer',
            description:
                'La app conserva historial, pero bloquea cotizar o reservar hasta activar un plan.',
          ),
        ];
      case MembershipAudience.provider:
        return const [
          MarketplaceModule(
            title: 'Onboarding del proveedor',
            description:
                'Demo para cargar flota, definir disponibilidad y recibir solicitudes simuladas.',
          ),
          MarketplaceModule(
            title: 'Plan operativo',
            description:
                'Acceso de paga para publicar aeronaves y cotizar rutas reales.',
          ),
          MarketplaceModule(
            title: 'Escala enterprise',
            description:
                'Mas usuarios internos, reportes, reglas de tarifa y soporte prioritario.',
          ),
        ];
      case MembershipAudience.admin:
        return const [
          MarketplaceModule(
            title: 'Gestionar demos',
            description:
                'Filtrar cuentas activas, por vencer y vencidas por rol.',
          ),
          MarketplaceModule(
            title: 'Administrar planes',
            description:
                'Precios, beneficios, permisos, comisiones y mensajes de conversion.',
          ),
          MarketplaceModule(
            title: 'Auditar pagos',
            description:
                'Monitorear suscripciones, facturacion, comisiones y bloqueos automaticos.',
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    const flowId = 'Centro de membresia::acciones';
    final workflow = context.watch<WorkflowProvider>();
    workflow.watch(
      flowId: flowId,
      initialRecords: const [
        StaticRecord(
          title: 'Demo 15 dias',
          subtitle: 'Cuenta en periodo gratuito con conversion pendiente.',
          status: 'Demo activa',
          amount: '15 dias',
        ),
      ],
    );

    Future<void> updateMembership(String title, String status) async {
      final provider = context.read<WorkflowProvider>();
      final current = provider.visibleRecords(flowId).first;
      final updated = current.copyWith(
        title: title,
        subtitle: 'Permisos, acceso y facturacion actualizados en la app.',
        status: status,
        amount: status == 'Activo' ? 'Plan vigente' : 'Upgrade listo',
      );
      provider.updateRecord(flowId, current, updated);
      if (!context.mounted) return;
      await showWorkflowRecordDetail(
        context,
        record: updated,
        onAdvance: () => provider.advanceRecord(flowId, updated),
        onActivate:
            () => provider.updateRecord(
              flowId,
              updated,
              updated.copyWith(status: 'Activo'),
            ),
        onBlock:
            () => provider.updateRecord(
              flowId,
              updated,
              updated.copyWith(status: 'Bloqueado'),
            ),
        onDelete: () => provider.deleteRecord(flowId, updated),
        onEdit: () async {
          final edited = await showWorkflowRecordForm(
            context,
            title: 'Editar membresia',
            initial: updated,
          );
          if (edited != null && context.mounted) {
            provider.updateRecord(flowId, updated, edited);
          }
        },
      );
    }

    return RoleDashboardScaffold(
      title: _title,
      subtitle: _subtitle,
      roleLabel: _roleLabel,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SubscriptionStatusBanner(),
          DashboardHero(
            eyebrow: 'SaaS premium',
            title: 'Demo gratuita de 15 dias con conversion a membresia',
            subtitle:
                'El flujo deja claro que la plataforma es de paga, permite probarla con confianza y guia el upgrade sin perder el tono ejecutivo.',
            primaryLabel: 'Activar plan',
            primaryAction: () => updateMembership('Plan Pro', 'Activo'),
            secondaryLabel: 'Mejorar suscripcion',
            secondaryAction:
                () => updateMembership('Plan Enterprise', 'Activo'),
          ),
          const SizedBox(height: 24),
          SectionHeading(title: _title, subtitle: _subtitle),
          const SizedBox(height: 14),
          MetricGrid(metrics: _metrics),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Planes',
            subtitle: 'Comparacion clara para demo, basico, pro y enterprise.',
          ),
          const SizedBox(height: 14),
          const PlanComparisonSection(),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Reglas visibles',
            subtitle:
                'Estados que deben aparecer durante todo el ciclo de vida de la cuenta.',
          ),
          const SizedBox(height: 14),
          ModuleList(items: _flow),
          const SizedBox(height: 24),
          const AccessLockCard(),
        ],
      ),
    );
  }
}
