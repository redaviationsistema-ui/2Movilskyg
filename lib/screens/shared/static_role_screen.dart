export '../../models/workflow_models.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/marketplace_models.dart';
import '../../models/workflow_models.dart';
import '../../providers/workflow_provider.dart';
import 'widgets/role_ui_components.dart';
import 'widgets/workflow_action_panel.dart';
import 'widgets/workflow_crud_sheet.dart';
import 'widgets/workflow_record_list.dart';

class StaticRoleScreen extends StatelessWidget {
  const StaticRoleScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.roleLabel,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.metrics,
    required this.modules,
    required this.records,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final String roleLabel;
  final String heroTitle;
  final String heroSubtitle;
  final List<MarketplaceMetric> metrics;
  final List<MarketplaceModule> modules;
  final List<StaticRecord> records;
  final List<StaticAction> actions;

  @override
  Widget build(BuildContext context) {
    final flowId = '$roleLabel::$title';
    final workflow = context.watch<WorkflowProvider>();
    final snapshot = workflow.watch(flowId: flowId, initialRecords: records);
    final visibleRecords = workflow.visibleRecords(flowId);
    final liveMetrics = [
      ...metrics,
      MarketplaceMetric(
        label: 'Operaciones',
        value: snapshot.operationCount.toString(),
        helper: snapshot.lastAudit,
      ),
    ];

    Future<void> runAction(StaticAction action) async {
      final label = action.label.toLowerCase();
      final provider = context.read<WorkflowProvider>();

      if (_isAgendaAction(label)) {
        await _openAgendaFlow(context, flowId, visibleRecords);
        return;
      }

      if (_isRequestAction(label)) {
        await _openRequestFlow(context, flowId, visibleRecords);
        return;
      }

      if (_isPhotoAction(label)) {
        await _openPhotoFlow(context, flowId, visibleRecords);
        return;
      }

      if (_isReportAction(label)) {
        await _openReportFlow(context, flowId, title, visibleRecords);
        return;
      }

      if (_isFilterAction(label)) {
        await _openAlertsFlow(context, flowId, visibleRecords);
        return;
      }

      if (_isCreateAction(label)) {
        final created = await showWorkflowRecordForm(
          context,
          title: 'Crear en $title',
        );
        if (created == null || !context.mounted) return;
        provider.createRecord(flowId, created);
        if (context.mounted) {
          await _openRecordDetail(context, flowId, created);
        }
        return;
      }

      if (_isEditAction(label)) {
        final target = visibleRecords.isNotEmpty ? visibleRecords.first : null;
        if (target == null) return;
        final updated = await showWorkflowRecordForm(
          context,
          title: 'Editar registro',
          initial: target,
        );
        if (updated == null || !context.mounted) return;
        provider.updateRecord(flowId, target, updated);
        if (context.mounted) {
          await _openRecordDetail(context, flowId, updated);
        }
        return;
      }

      if (_statusFor(label) case final status?) {
        final updated = provider.applyStatusToFirstActionable(
          flowId,
          status: status,
          suffix: status.toLowerCase(),
        );
        if (updated != null && context.mounted) {
          await _openRecordDetail(context, flowId, updated);
        }
        return;
      }
      await showWorkflowActionView(
        context,
        title: action.label,
        subtitle: action.message,
        records: visibleRecords,
        onCreate: () async {
          Navigator.pop(context);
          final created = await showWorkflowRecordForm(
            context,
            title: 'Crear registro',
          );
          if (created != null && context.mounted) {
            provider.createRecord(flowId, created);
          }
        },
        onClose: () => Navigator.pop(context),
      );
    }

    return RoleDashboardScaffold(
      title: title,
      subtitle: subtitle,
      roleLabel: roleLabel,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DashboardHero(
            eyebrow: roleLabel,
            title: heroTitle,
            subtitle: heroSubtitle,
            primaryLabel: actions.first.label,
            primaryAction: () => runAction(actions.first),
            secondaryLabel:
                actions.length > 1 ? actions[1].label : 'Ver detalle',
            secondaryAction:
                () =>
                    actions.length > 1
                        ? runAction(actions[1])
                        : showWorkflowActionView(
                          context,
                          title: 'Detalle operativo',
                          subtitle:
                              'Registros actuales conectados al flujo local.',
                          records: visibleRecords,
                          onCreate: () async {
                            Navigator.pop(context);
                            final created = await showWorkflowRecordForm(
                              context,
                              title: 'Crear registro',
                            );
                            if (created != null && context.mounted) {
                              context.read<WorkflowProvider>().createRecord(
                                flowId,
                                created,
                              );
                            }
                          },
                          onClose: () => Navigator.pop(context),
                        ),
          ),
          const SizedBox(height: 24),
          WorkflowAuditCard(
            operationCount: snapshot.operationCount,
            lastAudit: snapshot.lastAudit,
          ),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Indicadores',
            subtitle: 'Resumen operativo con datos vivos de la simulacion.',
          ),
          const SizedBox(height: 14),
          MetricGrid(metrics: liveMetrics),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Acciones',
            subtitle: 'Controles principales conectados al flujo de trabajo.',
          ),
          const SizedBox(height: 14),
          WorkflowActionPanel(actions: actions, onAction: runAction),
          const SizedBox(height: 24),
          SectionHeading(
            title: 'Registros',
            subtitle:
                snapshot.onlyAttention
                    ? 'Mostrando solo registros que requieren atencion.'
                    : 'Registros operativos con cambios reales en pantalla.',
          ),
          const SizedBox(height: 14),
          WorkflowRecordList(
            records: visibleRecords,
            onRecordTap: (record) => _openRecordDetail(context, flowId, record),
          ),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Flujo de trabajo',
            subtitle: 'Bloques que muestran como opera esta seccion.',
          ),
          const SizedBox(height: 14),
          ModuleList(items: modules),
        ],
      ),
    );
  }

  bool _isCreateAction(String label) {
    return label.contains('crear') ||
        label.contains('nueva') ||
        label.contains('alta') ||
        label.contains('subir') ||
        label.contains('invitar');
  }

  bool _isEditAction(String label) {
    return label.contains('editar') ||
        label.contains('actualizar') ||
        label.contains('cambiar') ||
        label.contains('metodo');
  }

  bool _isFilterAction(String label) {
    return label.contains('filtrar') || label == 'ver alertas';
  }

  bool _isAgendaAction(String label) {
    return label.contains('agenda') ||
        label.contains('calendario') ||
        label.contains('disponibilidad');
  }

  bool _isRequestAction(String label) {
    return label.contains('responder solicitud') ||
        label.contains('responder solicitudes') ||
        label.contains('cotizar solicitud');
  }

  bool _isPhotoAction(String label) {
    return label.contains('foto') ||
        label.contains('imagen') ||
        label.contains('imagenes');
  }

  bool _isReportAction(String label) {
    return label.contains('exportar') || label.contains('reporte');
  }

  String? _statusFor(String label) {
    if (label.contains('rechazar')) return 'Rechazado';
    if (label.contains('bloquear')) return 'Bloqueado';
    if (label.contains('contraofertar')) return 'Contraoferta';
    if (label.contains('iniciar')) return 'En curso';
    if (label.contains('aceptar') ||
        label.contains('aprobar') ||
        label.contains('activar') ||
        label.contains('confirmar') ||
        label.contains('liberar') ||
        label.contains('finalizar') ||
        label.contains('marcar aceptada')) {
      return 'Confirmado';
    }
    return null;
  }

  Future<void> _openRecordDetail(
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

  Future<void> _openAgendaFlow(
    BuildContext context,
    String flowId,
    List<StaticRecord> currentRecords,
  ) async {
    final provider = context.read<WorkflowProvider>();
    final created = await showAgendaWorkflowSheet(
      context,
      aircraft: currentRecords.isNotEmpty ? currentRecords.first.title : null,
    );
    if (created == null || !context.mounted) return;
    provider.createRecord(flowId, created);
    await _openRecordDetail(context, flowId, created);
  }

  Future<void> _openRequestFlow(
    BuildContext context,
    String flowId,
    List<StaticRecord> currentRecords,
  ) async {
    final provider = context.read<WorkflowProvider>();
    StaticRecord? target;
    for (final record in currentRecords) {
      final status = record.status.toLowerCase();
      if (status.contains('nueva') ||
          status.contains('pendiente') ||
          status.contains('revision')) {
        target = record;
        break;
      }
    }
    target ??= currentRecords.isNotEmpty ? currentRecords.first : null;

    final result = await showRequestResponseSheet(context, request: target);
    if (result == null || !context.mounted) return;

    if (target == null) {
      provider.createRecord(flowId, result);
    } else {
      provider.updateRecord(flowId, target, result);
    }
    await _openRecordDetail(context, flowId, result);
  }

  Future<void> _openPhotoFlow(
    BuildContext context,
    String flowId,
    List<StaticRecord> currentRecords,
  ) async {
    final provider = context.read<WorkflowProvider>();
    final target = currentRecords.isNotEmpty ? currentRecords.first : null;
    final result = await showPhotoUploadWorkflowSheet(
      context,
      aircraft: target,
    );
    if (result == null || !context.mounted) return;
    provider.createRecord(flowId, result);
    await _openRecordDetail(context, flowId, result);
  }

  Future<void> _openAlertsFlow(
    BuildContext context,
    String flowId,
    List<StaticRecord> currentRecords,
  ) async {
    final provider = context.read<WorkflowProvider>();
    provider.toggleAttentionFilter(flowId);
    if (!context.mounted) return;
    final alerts =
        context.read<WorkflowProvider>().visibleRecords(flowId).isNotEmpty
            ? context.read<WorkflowProvider>().visibleRecords(flowId)
            : currentRecords;
    await showAlertsWorkflowSheet(
      context,
      records: alerts,
      onOpen: (record) {
        Navigator.pop(context);
        _openRecordDetail(context, flowId, record);
      },
    );
  }

  Future<void> _openReportFlow(
    BuildContext context,
    String flowId,
    String title,
    List<StaticRecord> currentRecords,
  ) async {
    final provider = context.read<WorkflowProvider>();
    final report = StaticRecord(
      title: 'Reporte $title',
      subtitle:
          'KPIs, alertas y registros visibles consolidados para revision ejecutiva.',
      status: 'Confirmado',
      amount: '${currentRecords.length} items',
    );
    provider.createRecord(flowId, report);
    if (!context.mounted) return;
    await showReportWorkflowSheet(
      context,
      title: 'Reporte $title',
      report: report,
      records: currentRecords,
      onOpenRecord: (record) {
        Navigator.pop(context);
        _openRecordDetail(context, flowId, record);
      },
    );
  }
}
