import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/marketplace_models.dart';
import '../../../models/workflow_models.dart';
import '../../../providers/reservation_provider.dart';
import '../../../providers/workflow_provider.dart';
import 'workflow_crud_sheet.dart';

class RoleDashboardScaffold extends StatelessWidget {
  const RoleDashboardScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.roleLabel,
    required this.body,
  });

  final String title;
  final String subtitle;
  final String roleLabel;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF07121D), Color(0xFF102438), Color(0xFF15354B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: _HeaderCard(
                title: title,
                subtitle: subtitle,
                roleLabel: roleLabel,
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(34),
                ),
                child: Container(color: const Color(0xFFF4F6F9), child: body),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.roleLabel,
  });

  final String title;
  final String subtitle;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 960;
    final scaffold = Scaffold.maybeOf(context);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0E2235), Color(0xFF132E45)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x42000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
        border: Border.all(color: const Color(0x3DE0B86E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE2BD79), Color(0xFFF0D49D)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.flight_takeoff_rounded,
                  color: Color(0xFF12273C),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roleLabel,
                      style: const TextStyle(
                        color: Color(0xFFE2BD79),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isWide)
                IconButton(
                  tooltip: 'Abrir menu',
                  onPressed: scaffold?.openDrawer,
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: Color(0xFFE2BD79),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReservationProvider>();

    if (provider.syncMessage == null || provider.syncMessage!.isEmpty) {
      return const SizedBox.shrink();
    }

    final background =
        provider.isOnline ? const Color(0xFFEAF6F0) : const Color(0xFFFFF4E5);
    final border =
        provider.isOnline ? const Color(0xFF82C9A3) : const Color(0xFFE6B566);
    final foreground =
        provider.isOnline ? const Color(0xFF0F5C38) : const Color(0xFF8A5A00);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [background, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            provider.isOnline ? Icons.cloud_done : Icons.cloud_off,
            color: foreground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.isOnline ? 'Datos sincronizados' : 'Sin conexion',
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  provider.syncMessage!,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
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

class DashboardHero extends StatelessWidget {
  const DashboardHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.primaryAction,
    required this.secondaryLabel,
    required this.secondaryAction,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final VoidCallback primaryAction;
  final String secondaryLabel;
  final VoidCallback secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0B1B2C), Color(0xFF16314A), Color(0xFF1E4765)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              eyebrow,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: primaryAction,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE2BD79),
                  foregroundColor: const Color(0xFF1A1A1A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                child: Text(primaryLabel),
              ),
              OutlinedButton(
                onPressed: secondaryAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.26)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                child: Text(secondaryLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE2BD79),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF10253A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF536274),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.metrics});

  final List<MarketplaceMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children:
                metrics
                    .map(
                      (metric) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MetricCard(metric: metric),
                      ),
                    )
                    .toList(),
          );
        }

        final crossAxisCount = constraints.maxWidth > 1100 ? 3 : 2;

        return GridView.builder(
          itemCount: metrics.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: crossAxisCount == 2 ? 1.65 : 1.45,
          ),
          itemBuilder: (_, index) => _MetricCard(metric: metrics[index]),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final MarketplaceMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF8FBFD)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4EAF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120E2238),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insights_outlined, color: Color(0xFFE0AF57)),
          const SizedBox(height: 10),
          Text(
            metric.label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF5D6B7B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            metric.value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0E2238),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            metric.helper,
            style: const TextStyle(height: 1.35, color: Color(0xFF536274)),
          ),
        ],
      ),
    );
  }
}

class FeatureEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget screen;

  const FeatureEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.screen,
  });
}

class FeatureNavigationGrid extends StatelessWidget {
  const FeatureNavigationGrid({super.key, required this.items});

  final List<FeatureEntry> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children:
                items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _FeatureTile(item: item),
                      ),
                    )
                    .toList(),
          );
        }

        final crossAxisCount = constraints.maxWidth > 1100 ? 3 : 2;

        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (_, index) => _FeatureTile(item: items[index]),
        );
      },
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.item});

  final FeatureEntry item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => item.screen));
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE4EAF0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120E2238),
              blurRadius: 20,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE2BD79), Color(0xFFF0D49D)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: const Color(0xFF10253A)),
            ),
            const SizedBox(height: 14),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0E2238),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.subtitle,
              style: const TextStyle(color: Color(0xFF536274), height: 1.35),
            ),
            const SizedBox(height: 14),
            const Text(
              'Abrir vista',
              style: TextStyle(
                color: Color(0xFF1E5D8C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeatureDetailScreen extends StatelessWidget {
  const FeatureDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.metrics,
    required this.sections,
  });

  final String title;
  final String subtitle;
  final List<MarketplaceMetric> metrics;
  final List<MarketplaceModule> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        child: Column(
          children: [
            _CompactFeatureHeader(title: title),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  const SectionHeading(
                    title: 'Resumen',
                    subtitle:
                        'Pantalla lista para crecer con logica, datos y componentes reales.',
                  ),
                  const SizedBox(height: 14),
                  MetricGrid(metrics: metrics),
                  const SizedBox(height: 24),
                  const SectionHeading(
                    title: 'Componentes',
                    subtitle:
                        'Bloques funcionales previstos para esta vista dentro del proyecto.',
                  ),
                  const SizedBox(height: 14),
                  ModuleList(items: sections),
                  const SizedBox(height: 18),
                  FeatureActionPanel(title: title),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactFeatureHeader extends StatelessWidget {
  const _CompactFeatureHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10263A), Color(0xFF16324A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1FE2BD79)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE2BD79), Color(0xFFF0D49D)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.flight_takeoff_rounded,
              color: Color(0xFF12273C),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cabina marketplace',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFE2BD79),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Vista ejecutiva con contexto claro y lectura rapida.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.north_east_rounded,
              color: Color(0xFFE2BD79),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class ModuleList extends StatelessWidget {
  const ModuleList({super.key, required this.items});

  final List<MarketplaceModule> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) => _ModuleTile(module: item)).toList(),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module});

  final MarketplaceModule module;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E9EF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0E2238),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE2BD79), Color(0xFFF0D49D)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.flight, color: Color(0xFF10253A)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E2238),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  module.description,
                  style: const TextStyle(
                    height: 1.35,
                    color: Color(0xFF536274),
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

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3E9EF)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF536274), height: 1.35),
      ),
    );
  }
}

class ChipWrap extends StatelessWidget {
  const ChipWrap({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          items
              .map(
                (item) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFFBFCFE)],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE3E9EF)),
                  ),
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: Color(0xFF0E2238),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }
}

class FeatureActionPanel extends StatelessWidget {
  const FeatureActionPanel({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final flowId = 'Acciones rapidas::$title';
    final workflow = context.watch<WorkflowProvider>();
    final snapshot = workflow.watch(
      flowId: flowId,
      initialRecords: [
        StaticRecord(
          title: '$title operativo',
          subtitle: 'Registro inicial listo para editar, filtrar o exportar.',
          status: 'Pendiente',
          amount: 'Base',
        ),
      ],
    );
    final visibleRecords = workflow.visibleRecords(flowId);

    Future<void> createRecord() async {
      final created = await showWorkflowRecordForm(
        context,
        title: 'Crear $title',
      );
      if (created == null || !context.mounted) return;
      context.read<WorkflowProvider>().createRecord(flowId, created);
      if (!context.mounted) return;
      await _openSharedRecordDetail(context, flowId, created);
    }

    Future<void> exportRecords() async {
      final provider = context.read<WorkflowProvider>();
      final report = StaticRecord(
        title: 'Reporte $title',
        subtitle: 'Reporte generado con ${visibleRecords.length} registros.',
        status: 'Confirmado',
        amount: 'PDF',
      );
      provider.createRecord(flowId, report);
      if (!context.mounted) return;
      await showWorkflowActionView(
        context,
        title: 'Exportacion de $title',
        subtitle: 'El reporte queda registrado en la lista operativa.',
        records: [report, ...visibleRecords],
        onCreate: () async {
          Navigator.pop(context);
          await createRecord();
        },
        onClose: () => Navigator.pop(context),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4EAF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100E2238),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acciones rapidas',
            style: TextStyle(
              color: Color(0xFF10253A),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Operaciones: ${snapshot.operationCount} | ${snapshot.lastAudit}',
            style: const TextStyle(
              color: Color(0xFF607080),
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: createRecord,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crear'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10253A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    () => context
                        .read<WorkflowProvider>()
                        .toggleAttentionFilter(flowId),
                icon: const Icon(Icons.tune_rounded),
                label: Text(snapshot.onlyAttention ? 'Ver todos' : 'Filtrar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10253A),
                  side: const BorderSide(color: Color(0xFFD5DEE7)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: exportRecords,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Exportar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10253A),
                  side: const BorderSide(color: Color(0xFFD5DEE7)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          if (visibleRecords.isNotEmpty) ...[
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap:
                  () => _openSharedRecordDetail(
                    context,
                    flowId,
                    visibleRecords.first,
                  ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4EAF0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.dataset_rounded, color: Color(0xFF10253A)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${visibleRecords.first.title} | ${visibleRecords.first.status}',
                        style: const TextStyle(
                          color: Color(0xFF10253A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SubscriptionStatusBanner extends StatelessWidget {
  const SubscriptionStatusBanner({
    super.key,
    this.daysRemaining = 12,
    this.status = 'Demo activa',
  });

  final int daysRemaining;
  final String status;

  @override
  Widget build(BuildContext context) {
    final progress = (daysRemaining / 15).clamp(0.0, 1.0);
    final flowId = 'Membresia::$status';
    final workflow = context.watch<WorkflowProvider>();
    workflow.watch(
      flowId: flowId,
      initialRecords: [
        StaticRecord(
          title: status,
          subtitle:
              'Cuenta con $daysRemaining dias restantes y acceso controlado por membresia.',
          status: status,
          amount: '$daysRemaining dias',
        ),
      ],
    );
    final account = workflow.visibleRecords(flowId).first;

    Future<void> setMembership(String plan, String state) async {
      final provider = context.read<WorkflowProvider>();
      final updated = account.copyWith(
        title: plan,
        subtitle: 'Membresia actualizada localmente con permisos del plan.',
        status: state,
        amount: state == 'Activo' ? 'Plan vigente' : 'Validado',
      );
      provider.updateRecord(flowId, account, updated);
      if (!context.mounted) return;
      await _openSharedRecordDetail(context, flowId, updated);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B1B2C), Color(0xFF16314A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x55E2BD79)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160E2238),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE2BD79), Color(0xFFF0D49D)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFF10253A),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: const TextStyle(
                        color: Color(0xFFE2BD79),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Plataforma de paga con prueba premium de 15 dias.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$daysRemaining dias restantes antes de requerir suscripcion.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFE2BD79),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                onPressed: () => setMembership('Plan Pro', 'Activo'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE2BD79),
                  foregroundColor: const Color(0xFF111111),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Activar plan'),
              ),
              OutlinedButton(
                onPressed:
                    () => _openSharedRecordDetail(
                      context,
                      flowId,
                      context
                          .read<WorkflowProvider>()
                          .visibleRecords(flowId)
                          .first,
                    ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Continuar con membresia'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Text(
              '${account.title} | ${account.status} | ${account.amount}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlanComparisonSection extends StatelessWidget {
  const PlanComparisonSection({super.key});

  static const List<_PlanData> _plans = [
    _PlanData(
      name: 'Demo 15 dias',
      price: '\$0',
      cadence: 'prueba',
      highlight: 'Explorar plataforma',
      benefits: ['Busqueda limitada', 'Resultados demo', 'Asistente simulado'],
    ),
    _PlanData(
      name: 'Plan Basico',
      price: '\$99',
      cadence: 'mes',
      highlight: 'Clientes frecuentes',
      benefits: ['Cotizaciones', 'Historial', 'Soporte estandar'],
    ),
    _PlanData(
      name: 'Plan Pro',
      price: '\$249',
      cadence: 'mes',
      highlight: 'Operacion activa',
      benefits: ['Reservas', 'Prioridad en solicitudes', 'Reportes y pagos'],
      featured: true,
    ),
    _PlanData(
      name: 'Empresarial',
      price: 'Personalizado',
      cadence: 'anual',
      highlight: 'Cuentas corporativas',
      benefits: ['SLA dedicado', 'Usuarios multiples', 'Integraciones'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final flowId = 'Membresia::planes';
    final workflow = _maybeWorkflow(context, listen: true);
    final snapshot = workflow?.watch(
      flowId: flowId,
      initialRecords:
          _plans
              .map(
                (plan) => StaticRecord(
                  title: plan.name,
                  subtitle: plan.highlight,
                  status: plan.name.contains('Demo') ? 'Demo activa' : 'Plan',
                  amount: plan.price,
                ),
              )
              .toList(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 780) {
          return Column(
            children:
                _plans
                    .map(
                      (plan) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PlanCard(
                          plan: plan,
                          flowId: flowId,
                          selected:
                              snapshot?.records.first.title ==
                              '${plan.name} activo',
                        ),
                      ),
                    )
                    .toList(),
          );
        }

        return GridView.builder(
          itemCount: _plans.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.18,
          ),
          itemBuilder:
              (_, index) => _PlanCard(
                plan: _plans[index],
                flowId: flowId,
                selected:
                    snapshot?.records.first.title ==
                    '${_plans[index].name} activo',
              ),
        );
      },
    );
  }
}

class AccessLockCard extends StatelessWidget {
  const AccessLockCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EA),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2BD79)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE2BD79).withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.lock_clock_rounded,
              color: Color(0xFF6C4C12),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vista de upgrade al terminar demo',
                  style: TextStyle(
                    color: Color(0xFF6C4C12),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Cuando la demo vence, la app debe bloquear cotizar, reservar o publicar flota, conservar datos y mostrar un CTA premium para activar la membresia.',
                  style: TextStyle(color: Color(0xFF7B612C), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanData {
  final String name;
  final String price;
  final String cadence;
  final String highlight;
  final List<String> benefits;
  final bool featured;

  const _PlanData({
    required this.name,
    required this.price,
    required this.cadence,
    required this.highlight,
    required this.benefits,
    this.featured = false,
  });
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.flowId,
    required this.selected,
  });

  final _PlanData plan;
  final String flowId;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final background = plan.featured ? const Color(0xFF10253A) : Colors.white;
    final foreground = plan.featured ? Colors.white : const Color(0xFF10253A);
    final muted =
        plan.featured
            ? Colors.white.withValues(alpha: 0.74)
            : const Color(0xFF607080);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              plan.featured ? const Color(0xFFE2BD79) : const Color(0xFFE4EAF0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120E2238),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (plan.featured)
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFE2BD79),
                  size: 20,
                ),
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF1B8F4D),
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(plan.highlight, style: TextStyle(color: muted, height: 1.35)),
          const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              text: plan.price,
              style: TextStyle(
                color: foreground,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
              children: [
                TextSpan(
                  text: ' / ${plan.cadence}',
                  style: TextStyle(
                    color: muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...plan.benefits.map(
            (benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFFE2BD79),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      benefit,
                      style: TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final provider = _maybeWorkflow(context);
                if (provider == null) {
                  await showWorkflowActionView(
                    context,
                    title: '${plan.name} seleccionado',
                    subtitle:
                        'Plan listo para conectarse al flujo de membresia.',
                    records: [
                      StaticRecord(
                        title: '${plan.name} activo',
                        subtitle: plan.highlight,
                        status:
                            plan.name.contains('Demo')
                                ? 'Demo activa'
                                : 'Activo',
                        amount: '${plan.price} / ${plan.cadence}',
                      ),
                    ],
                    onCreate: () => Navigator.pop(context),
                    onClose: () => Navigator.pop(context),
                  );
                  return;
                }
                final current = provider.visibleRecords(flowId).first;
                final updated = StaticRecord(
                  title: '${plan.name} activo',
                  subtitle:
                      'Checkout local completado. Beneficios habilitados: ${plan.benefits.join(', ')}.',
                  status: plan.name.contains('Demo') ? 'Demo activa' : 'Activo',
                  amount: '${plan.price} / ${plan.cadence}',
                );
                provider.updateRecord(flowId, current, updated);
                if (!context.mounted) return;
                await _openSharedRecordDetail(context, flowId, updated);
              },
              style: FilledButton.styleFrom(
                backgroundColor:
                    plan.featured
                        ? const Color(0xFFE2BD79)
                        : const Color(0xFF10253A),
                foregroundColor:
                    plan.featured ? const Color(0xFF111111) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                plan.featured ? 'Mejorar suscripcion' : 'Seleccionar plan',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

WorkflowProvider? _maybeWorkflow(BuildContext context, {bool listen = false}) {
  try {
    return Provider.of<WorkflowProvider>(context, listen: listen);
  } on ProviderNotFoundException {
    return null;
  }
}

Future<void> _openSharedRecordDetail(
  BuildContext context,
  String flowId,
  StaticRecord record,
) {
  final provider = context.read<WorkflowProvider>();
  return showWorkflowRecordDetail(
    context,
    record: record,
    onAdvance: () => provider.advanceRecord(flowId, record),
    onActivate:
        () => provider.updateRecord(
          flowId,
          record,
          record.copyWith(
            status: 'Activo',
            subtitle: '${record.subtitle} | activado',
          ),
        ),
    onBlock:
        () => provider.updateRecord(
          flowId,
          record,
          record.copyWith(
            status: 'Bloqueado',
            subtitle: '${record.subtitle} | bloqueado',
          ),
        ),
    onDelete: () => provider.deleteRecord(flowId, record),
    onEdit: () async {
      final updated = await showWorkflowRecordForm(
        context,
        title: 'Editar registro',
        initial: record,
      );
      if (updated != null && context.mounted) {
        provider.updateRecord(flowId, record, updated);
      }
    },
  );
}
