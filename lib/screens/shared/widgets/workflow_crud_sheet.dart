import 'package:flutter/material.dart';

import '../../../models/workflow_models.dart';

Future<StaticRecord?> showWorkflowRecordForm(
  BuildContext context, {
  required String title,
  StaticRecord? initial,
}) {
  return showModalBottomSheet<StaticRecord>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _WorkflowRecordForm(title: title, initial: initial),
  );
}

Future<void> showWorkflowRecordDetail(
  BuildContext context, {
  required StaticRecord record,
  required VoidCallback onAdvance,
  required VoidCallback onActivate,
  required VoidCallback onBlock,
  required VoidCallback onDelete,
  required Future<void> Function() onEdit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.title,
              style: const TextStyle(
                color: Color(0xFF10253A),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              record.subtitle,
              style: const TextStyle(color: Color(0xFF607080), height: 1.35),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DetailChip(label: record.status),
                _DetailChip(label: record.amount),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onAdvance();
                  },
                  icon: const Icon(Icons.trending_up_rounded),
                  label: const Text('Avanzar'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await onEdit();
                  },
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Editar'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onActivate();
                  },
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Activar'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onBlock();
                  },
                  icon: const Icon(Icons.block_rounded),
                  label: const Text('Bloquear'),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Eliminar'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showWorkflowActionView(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<StaticRecord> records,
  required VoidCallback onCreate,
  required VoidCallback onClose,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, controller) {
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF10253A),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF607080), height: 1.35),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Crear registro'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onClose,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Listo'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ...records.map(
                (record) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE4EAF0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title,
                        style: const TextStyle(
                          color: Color(0xFF10253A),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        record.subtitle,
                        style: const TextStyle(
                          color: Color(0xFF607080),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          _DetailChip(label: record.status),
                          _DetailChip(label: record.amount),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<StaticRecord?> showAgendaWorkflowSheet(
  BuildContext context, {
  String? aircraft,
}) {
  return showModalBottomSheet<StaticRecord>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AgendaWorkflowSheet(aircraft: aircraft),
  );
}

Future<StaticRecord?> showRequestResponseSheet(
  BuildContext context, {
  StaticRecord? request,
}) {
  return showModalBottomSheet<StaticRecord>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RequestResponseSheet(request: request),
  );
}

Future<StaticRecord?> showPhotoUploadWorkflowSheet(
  BuildContext context, {
  StaticRecord? aircraft,
}) {
  return showModalBottomSheet<StaticRecord>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PhotoUploadWorkflowSheet(aircraft: aircraft),
  );
}

Future<void> showAlertsWorkflowSheet(
  BuildContext context, {
  required List<StaticRecord> records,
  required ValueChanged<StaticRecord> onOpen,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (_) => _RecordsDashboardSheet(
          title: 'Alertas operativas',
          subtitle:
              'Pendientes, revisiones, bloqueos y casos criticos listos para abrir.',
          records: records,
          primaryLabel: 'Abrir alerta',
          onOpen: onOpen,
          header: _AlertSummary(records: records),
        ),
  );
}

Future<void> showReportWorkflowSheet(
  BuildContext context, {
  required String title,
  required StaticRecord report,
  required List<StaticRecord> records,
  required ValueChanged<StaticRecord> onOpenRecord,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (_) => _RecordsDashboardSheet(
          title: title,
          subtitle: report.subtitle,
          records: records,
          primaryLabel: 'Abrir registro',
          onOpen: onOpenRecord,
          header: _ReportSummary(records: records),
        ),
  );
}

class _AgendaWorkflowSheet extends StatefulWidget {
  const _AgendaWorkflowSheet({this.aircraft});

  final String? aircraft;

  @override
  State<_AgendaWorkflowSheet> createState() => _AgendaWorkflowSheetState();
}

class _AgendaWorkflowSheetState extends State<_AgendaWorkflowSheet> {
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 13, minute: 0);
  String _action = 'Bloquear';
  final _noteController = TextEditingController(text: 'Ventana operativa');

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actualizar agenda',
            style: TextStyle(
              color: Color(0xFF10253A),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.aircraft == null
                ? 'Crea un bloqueo, liberacion o mantenimiento.'
                : 'Agenda para ${widget.aircraft}.',
            style: const TextStyle(color: Color(0xFF607080), height: 1.35),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            children:
                ['Bloquear', 'Liberar', 'Mantenimiento'].map((item) {
                  final selected = item == _action;
                  return ChoiceChip(
                    label: Text(item),
                    selected: selected,
                    onSelected: (_) => setState(() => _action = item),
                  );
                }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  icon: const Icon(Icons.event_rounded),
                  label: Text('${_date.day}/${_date.month}/${_date.year}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _start,
                    );
                    if (picked != null) setState(() => _start = picked);
                  },
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(_start.format(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _end,
              );
              if (picked != null) setState(() => _end = picked);
            },
            icon: const Icon(Icons.timelapse_rounded),
            label: Text('Fin ${_end.format(context)}'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Nota operativa',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  context,
                  StaticRecord(
                    title: '${widget.aircraft ?? 'Aeronave'} | $_action',
                    subtitle:
                        '${_noteController.text.trim()} | ${_date.day}/${_date.month}/${_date.year} ${_start.format(context)}-${_end.format(context)}',
                    status: _action,
                    amount: _start.format(context),
                  ),
                );
              },
              icon: const Icon(Icons.save_rounded),
              label: const Text('Guardar agenda'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestResponseSheet extends StatefulWidget {
  const _RequestResponseSheet({this.request});

  final StaticRecord? request;

  @override
  State<_RequestResponseSheet> createState() => _RequestResponseSheetState();
}

class _RequestResponseSheetState extends State<_RequestResponseSheet> {
  String _decision = 'Aceptar';
  late final TextEditingController _amountController;
  final _noteController = TextEditingController(
    text: 'Oferta sujeta a slots, tripulacion y permisos.',
  );

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.request?.amount ?? '\$18,900 USD',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Responder solicitud',
            style: TextStyle(
              color: Color(0xFF10253A),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            request == null
                ? 'Crea una respuesta comercial para el cliente.'
                : '${request.title} | ${request.subtitle}',
            style: const TextStyle(color: Color(0xFF607080), height: 1.35),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            children:
                ['Aceptar', 'Contraofertar', 'Rechazar'].map((item) {
                  return ChoiceChip(
                    label: Text(item),
                    selected: item == _decision,
                    onSelected: (_) => setState(() => _decision = item),
                  );
                }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Precio / oferta',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Mensaje al cliente',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                final status =
                    _decision == 'Aceptar'
                        ? 'Confirmado'
                        : _decision == 'Rechazar'
                        ? 'Rechazado'
                        : 'Contraoferta';
                Navigator.pop(
                  context,
                  StaticRecord(
                    title: request?.title ?? 'Nueva respuesta',
                    subtitle: '${_noteController.text.trim()} | $_decision',
                    status: status,
                    amount: _amountController.text.trim(),
                  ),
                );
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('Enviar respuesta'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoUploadWorkflowSheet extends StatefulWidget {
  const _PhotoUploadWorkflowSheet({this.aircraft});

  final StaticRecord? aircraft;

  @override
  State<_PhotoUploadWorkflowSheet> createState() =>
      _PhotoUploadWorkflowSheetState();
}

class _PhotoUploadWorkflowSheetState extends State<_PhotoUploadWorkflowSheet> {
  int _photos = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cargar imagenes',
            style: TextStyle(
              color: Color(0xFF10253A),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.aircraft == null
                ? 'Agrega imagenes de cabina, exterior y amenidades.'
                : 'Aeronave: ${widget.aircraft!.title}',
            style: const TextStyle(color: Color(0xFF607080), height: 1.35),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      () => setState(() => _photos = (_photos + 1).clamp(0, 6)),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Galeria'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      () => setState(() => _photos = (_photos + 1).clamp(0, 6)),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('Camara'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemBuilder: (_, index) {
              final active = index < _photos;
              return Container(
                decoration: BoxDecoration(
                  color:
                      active
                          ? const Color(0xFF10253A)
                          : const Color(0xFFF4F6F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4EAF0)),
                ),
                child: Icon(
                  active ? Icons.image_rounded : Icons.add_photo_alternate,
                  color:
                      active
                          ? const Color(0xFFE2BD79)
                          : const Color(0xFF607080),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  _photos == 0
                      ? null
                      : () {
                        Navigator.pop(
                          context,
                          StaticRecord(
                            title:
                                '${widget.aircraft?.title ?? 'Aeronave'} | fotos',
                            subtitle:
                                'Galeria local actualizada con $_photos imagenes visibles.',
                            status: 'Activo',
                            amount: '$_photos fotos',
                          ),
                        );
                      },
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text('Guardar imagenes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordsDashboardSheet extends StatelessWidget {
  const _RecordsDashboardSheet({
    required this.title,
    required this.subtitle,
    required this.records,
    required this.primaryLabel,
    required this.onOpen,
    required this.header,
  });

  final String title;
  final String subtitle;
  final List<StaticRecord> records;
  final String primaryLabel;
  final ValueChanged<StaticRecord> onOpen;
  final Widget header;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF10253A),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF607080), height: 1.35),
            ),
            const SizedBox(height: 18),
            header,
            const SizedBox(height: 18),
            ...records.map(
              (record) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE4EAF0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: const TextStyle(
                        color: Color(0xFF10253A),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      record.subtitle,
                      style: const TextStyle(
                        color: Color(0xFF607080),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _DetailChip(label: record.status),
                        const SizedBox(width: 8),
                        _DetailChip(label: record.amount),
                        const Spacer(),
                        TextButton(
                          onPressed: () => onOpen(record),
                          child: Text(primaryLabel),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AlertSummary extends StatelessWidget {
  const _AlertSummary({required this.records});

  final List<StaticRecord> records;

  @override
  Widget build(BuildContext context) {
    return _SummaryBand(
      icon: Icons.warning_rounded,
      title: '${records.length} alertas visibles',
      subtitle: 'Toca una alerta para validar, bloquear, editar o eliminar.',
    );
  }
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.records});

  final List<StaticRecord> records;

  @override
  Widget build(BuildContext context) {
    final confirmed =
        records
            .where((record) => record.status.toLowerCase().contains('confirm'))
            .length;
    final pending =
        records
            .where((record) => record.status.toLowerCase().contains('pend'))
            .length;

    return Column(
      children: [
        _SummaryBand(
          icon: Icons.query_stats_rounded,
          title: 'Reporte visual generado',
          subtitle: '$confirmed confirmados | $pending pendientes',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiTile(label: 'Registros', value: '${records.length}'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiTile(label: 'Confirmados', value: '$confirmed'),
            ),
            const SizedBox(width: 10),
            Expanded(child: _KpiTile(label: 'Pendientes', value: '$pending')),
          ],
        ),
      ],
    );
  }
}

class _SummaryBand extends StatelessWidget {
  const _SummaryBand({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10253A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE2BD79)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF607080),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF10253A),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowRecordForm extends StatefulWidget {
  const _WorkflowRecordForm({required this.title, this.initial});

  final String title;
  final StaticRecord? initial;

  @override
  State<_WorkflowRecordForm> createState() => _WorkflowRecordFormState();
}

class _WorkflowRecordFormState extends State<_WorkflowRecordForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _statusController;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initial?.title ?? '');
    _subtitleController = TextEditingController(
      text: widget.initial?.subtitle ?? '',
    );
    _statusController = TextEditingController(
      text: widget.initial?.status ?? 'Pendiente',
    );
    _amountController = TextEditingController(
      text: widget.initial?.amount ?? 'Nuevo',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _statusController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: Color(0xFF10253A),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Nombre / titulo',
                border: OutlineInputBorder(),
              ),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Campo obligatorio'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subtitleController,
              decoration: const InputDecoration(
                labelText: 'Detalle',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 3,
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Campo obligatorio'
                          : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _statusController,
                    decoration: const InputDecoration(
                      labelText: 'Estatus',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Importe / valor',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    StaticRecord(
                      title: _titleController.text.trim(),
                      subtitle: _subtitleController.text.trim(),
                      status:
                          _statusController.text.trim().isEmpty
                              ? 'Pendiente'
                              : _statusController.text.trim(),
                      amount:
                          _amountController.text.trim().isEmpty
                              ? 'Nuevo'
                              : _amountController.text.trim(),
                    ),
                  );
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE2BD79).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF10253A),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
