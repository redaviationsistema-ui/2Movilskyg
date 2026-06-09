part of 'pantalla_espacio_sobrecargo.dart';

class _DashboardView extends StatelessWidget {
  const _DashboardView({
    required this.assignments,
    required this.incidents,
    required this.documents,
    required this.onScan,
  });

  final List<CrewAssignment> assignments;
  final List<CrewIncident> incidents;
  final List<CrewDocument> documents;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final active =
        assignments.where((item) => item.status != 'Finalizada').length;
    final expiredDocs =
        documents.where((item) => item.status.contains('Vence')).length;

    return Column(
      children: [
        _OperationalStrip(
          title: 'Briefing de cabina',
          subtitle:
              'Asignaciones, documentos e incidencias sincronizados para operacion segura.',
          status: active > 0 ? 'Operacion activa' : 'Sin misiones activas',
        ),
        const SizedBox(height: 14),
        _MetricGrid(
          metrics: [
            _Metric('Misiones', '$active', Icons.flight_rounded),
            _Metric(
              'Incidencias',
              '${incidents.length}',
              Icons.warning_rounded,
            ),
            _Metric('Docs alerta', '$expiredDocs', Icons.folder_rounded),
            _Metric('Estado', 'Disponible', Icons.verified_user_rounded),
          ],
        ),
        const SizedBox(height: 14),
        _ActionCard(
          title: 'Briefing operativo',
          subtitle:
              'Revisa proveedor, aeronave, presentacion, pasajeros y codigo de check-in.',
          icon: Icons.qr_code_scanner_rounded,
          button: 'Escanear QR',
          onPressed: onScan,
        ),
        const SizedBox(height: 14),
        ...assignments.take(2).map((item) => _AssignmentCard(item: item)),
      ],
    );
  }
}

class _OperationalStrip extends StatelessWidget {
  const _OperationalStrip({
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    return _AnimatedEntry(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF07121D), Color(0xFF12304A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0x33E0B86E)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 22,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE0B86E), Color(0xFFF2D39C)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.airlines_rounded,
                color: Color(0xFF07121D),
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
                      color: Color(0xFFE0B86E),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFD8E2EA),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionList extends StatelessWidget {
  const _MissionList({
    required this.assignments,
    required this.onAccept,
    required this.onReject,
    required this.onRequestChange,
    required this.onAdvance,
  });

  final List<CrewAssignment> assignments;
  final ValueChanged<CrewAssignment> onAccept;
  final ValueChanged<CrewAssignment> onReject;
  final ValueChanged<CrewAssignment> onRequestChange;
  final void Function(CrewAssignment, CrewMissionAction) onAdvance;

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return const _InfoTile(
        icon: Icons.assignment_turned_in_rounded,
        title: 'Sin misiones asignadas',
        subtitle: 'Cuando admin publique una operacion aparecera aqui.',
      );
    }

    return Column(
      children:
          assignments.map((item) {
            final nextAction = item.nextAction;
            return _AssignmentCard(
              item: item,
              actions:
                  item.canRespondToAssignment
                      ? [
                        OutlinedButton.icon(
                          onPressed: () => onReject(item),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Rechazar'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => onRequestChange(item),
                          icon: const Icon(Icons.edit_note_rounded),
                          label: const Text('Revision'),
                        ),
                        FilledButton.icon(
                          onPressed: () => onAccept(item),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Confirmar'),
                        ),
                      ]
                      : nextAction == null
                      ? const []
                      : [
                        FilledButton.icon(
                          onPressed: () => onAdvance(item, nextAction),
                          icon: Icon(nextAction.icon),
                          label: Text(nextAction.label),
                        ),
                      ],
            );
          }).toList(),
    );
  }
}

class _CalendarView extends StatelessWidget {
  const _CalendarView({
    required this.selectedDate,
    required this.assignments,
    required this.blocks,
    required this.onDateSelected,
    required this.onBlock,
  });

  final DateTime selectedDate;
  final List<CrewAssignment> assignments;
  final List<CrewBlock> blocks;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final dayItems =
        assignments
            .where((item) => isSameDay(item.date, selectedDate))
            .toList();
    final dayBlocks =
        blocks.where((item) => isSameDay(item.date, selectedDate)).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: _panelDecoration(),
          child: TableCalendar<CrewAssignment>(
            firstDay: DateTime.now().subtract(const Duration(days: 90)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: selectedDate,
            selectedDayPredicate: (day) => isSameDay(day, selectedDate),
            onDaySelected: (selected, _) => onDateSelected(selected),
            eventLoader:
                (day) =>
                    assignments
                        .where((item) => isSameDay(item.date, day))
                        .toList(),
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Color(0xFFE0B86E),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _ActionCard(
          title: 'Disponibilidad personal',
          subtitle: 'Bloquea agenda para descanso, capacitacion o restriccion.',
          icon: Icons.event_busy_rounded,
          button: 'Bloquear dia',
          onPressed: onBlock,
        ),
        const SizedBox(height: 14),
        ...dayBlocks.map(
          (item) => _InfoTile(
            icon: Icons.block_rounded,
            title: 'Bloqueo de agenda',
            subtitle: item.reason,
          ),
        ),
        ...dayItems.map((item) => _AssignmentCard(item: item)),
      ],
    );
  }
}

class _AvailabilityView extends StatefulWidget {
  const _AvailabilityView({
    required this.selectedDate,
    required this.assignments,
    required this.records,
    required this.statuses,
    required this.isLoading,
    required this.onDateSelected,
    required this.onMonthChanged,
    required this.onSave,
    required this.onRequestChange,
  });

  final DateTime selectedDate;
  final List<CrewAssignment> assignments;
  final List<CrewAvailabilityRecord> records;
  final List<CrewAvailabilityStatus> statuses;
  final bool isLoading;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onMonthChanged;
  final Future<void> Function(DateTime, String, String) onSave;
  final Future<void> Function(DateTime) onRequestChange;

  @override
  State<_AvailabilityView> createState() => _AvailabilityViewState();
}

class _AvailabilityViewState extends State<_AvailabilityView> {
  late final TextEditingController _commentController;
  String _selectedStatus = 'DISPONIBLE';

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    _syncEditor();
  }

  @override
  void didUpdateWidget(covariant _AvailabilityView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldRecord = _recordFor(oldWidget.records, oldWidget.selectedDate);
    final newRecord = _selectedRecord;
    if (!isSameDay(oldWidget.selectedDate, widget.selectedDate) ||
        oldRecord?.statusKey != newRecord?.statusKey ||
        oldRecord?.comment != newRecord?.comment) {
      _syncEditor();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  CrewAvailabilityRecord? get _selectedRecord =>
      _recordFor(widget.records, widget.selectedDate);

  CrewAvailabilityRecord? _recordFor(
    List<CrewAvailabilityRecord> records,
    DateTime day,
  ) {
    for (final record in records) {
      if (isSameDay(record.date, day)) return record;
    }
    return null;
  }

  void _syncEditor() {
    final record = _selectedRecord;
    final selectableKeys = widget.statuses.map((item) => item.key).toSet();
    final candidate = record?.statusKey ?? 'DISPONIBLE';
    _selectedStatus =
        selectableKeys.contains(candidate)
            ? candidate
            : (widget.statuses.isEmpty
                ? 'DISPONIBLE'
                : widget.statuses.first.key);
    _commentController.text = record?.comment ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final selectedRecord = _selectedRecord;
    final operation = _operationFor(widget.selectedDate);
    final locked = selectedRecord?.isOperation == true;
    final activity =
        widget.records
            .where(
              (item) =>
                  item.isStored &&
                  item.statusKey != 'POR_CONFIRMAR' &&
                  item.statusKey != 'EN_OPERACION',
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OperationalStrip(
          title: 'Calendario mensual',
          subtitle:
              'Marca tus dias disponibles, descanso o restricciones para que admin pueda planear operaciones.',
          status: widget.isLoading ? 'Actualizando...' : 'Sincronizado',
        ),
        const SizedBox(height: 14),
        _availabilitySummary(),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: _panelDecoration(),
          child: TableCalendar<CrewAvailabilityRecord>(
            locale: 'es_MX',
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 730)),
            focusedDay: widget.selectedDate,
            selectedDayPredicate: (day) => isSameDay(day, widget.selectedDate),
            onDaySelected: (selected, _) => widget.onDateSelected(selected),
            onPageChanged: widget.onMonthChanged,
            eventLoader: (day) {
              final record = _recordFor(widget.records, day);
              return record == null ? [] : [record];
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder:
                  (context, day, focusedDay) => _dayCell(day, false),
              todayBuilder: (context, day, focusedDay) => _dayCell(day, false),
              selectedBuilder:
                  (context, day, focusedDay) => _dayCell(day, true),
              markerBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (locked)
          _operationEditor(operation, selectedRecord)
        else
          _availabilityEditor(selectedRecord),
        if (activity.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text(
            'Actividad reciente',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ...activity
              .take(6)
              .map(
                (item) => _InfoTile(
                  icon: Icons.history_rounded,
                  title: '${_dateLabel(item.date)} | ${item.label}',
                  subtitle:
                      item.comment.isEmpty
                          ? 'Actualizado desde ${item.origin.toLowerCase()}.'
                          : item.comment,
                ),
              ),
        ],
      ],
    );
  }

  Widget _availabilitySummary() {
    final keys = [
      'DISPONIBLE',
      'DESCANSO',
      'NO_DISPONIBLE',
      'BLOQUEO_SOLICITADO',
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          keys.map((key) {
            final status = _statusFor(key);
            final count =
                widget.records.where((item) => item.statusKey == key).length;
            return Container(
              width: 155,
              padding: const EdgeInsets.all(13),
              decoration: _panelDecoration(),
              child: Row(
                children: [
                  CircleAvatar(radius: 7, backgroundColor: status.color),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$count dias',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          status.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF5F6975),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _dayCell(DateTime day, bool selected) {
    final record = _recordFor(widget.records, day);
    final color = record?.color ?? const Color(0xFFE2E8F0);
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 1 : 0.18),
          shape: BoxShape.circle,
          border:
              selected
                  ? Border.all(color: const Color(0xFF0E2338), width: 2)
                  : null,
        ),
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF15293A),
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _availabilityEditor(CrewAvailabilityRecord? record) {
    final selectable =
        widget.statuses.where((item) => item.selectable).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Disponibilidad del ${_dateLabel(widget.selectedDate)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            record?.label ?? 'Sin estado registrado',
            style: TextStyle(
              color: record?.color ?? const Color(0xFF5F6975),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                selectable.map((status) {
                  return ChoiceChip(
                    selected: _selectedStatus == status.key,
                    label: Text(status.label),
                    avatar: CircleAvatar(
                      radius: 6,
                      backgroundColor: status.color,
                    ),
                    onSelected:
                        (_) => setState(() => _selectedStatus = status.key),
                  );
                }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Comentario o motivo',
              hintText: 'Agrega contexto para operaciones',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  widget.isLoading
                      ? null
                      : () => widget.onSave(
                        widget.selectedDate,
                        _selectedStatus,
                        _commentController.text.trim(),
                      ),
              icon: const Icon(Icons.save_rounded),
              label: const Text('Guardar disponibilidad'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _operationEditor(
    CrewAssignment? operation,
    CrewAvailabilityRecord? record,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration().copyWith(
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dia asignado a operacion',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            operation == null
                ? record?.comment ?? 'La operacion fue asignada por admin.'
                : '${operation.code} | ${operation.route} | ${operation.showTime}',
            style: const TextStyle(color: Color(0xFF41566A), height: 1.4),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed:
                widget.isLoading
                    ? null
                    : () => widget.onRequestChange(widget.selectedDate),
            icon: const Icon(Icons.edit_calendar_rounded),
            label: const Text('Solicitar cambio'),
          ),
        ],
      ),
    );
  }

  CrewAssignment? _operationFor(DateTime day) {
    for (final assignment in widget.assignments) {
      if (isSameDay(assignment.date, day) &&
          !assignment.status.toLowerCase().contains('rechaz')) {
        return assignment;
      }
    }
    return null;
  }

  CrewAvailabilityStatus _statusFor(String key) {
    for (final status in widget.statuses) {
      if (status.key == key) return status;
    }
    for (final status in CrewAvailabilityStatus.defaults) {
      if (status.key == key) return status;
    }
    return CrewAvailabilityStatus(
      key: key,
      label: key.replaceAll('_', ' '),
      description: '',
      color: const Color(0xFF94A3B8),
    );
  }

  String _dateLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _InfoTile(
          icon: Icons.person_pin_rounded,
          title: 'Perfil de vuelo',
          subtitle: 'Base MMTO, cabina ejecutiva, servicio VIP, idiomas ES/EN.',
        ),
        _InfoTile(
          icon: Icons.health_and_safety_rounded,
          title: 'Certificaciones',
          subtitle: 'CRM, primeros auxilios, evacuacion, servicio a bordo.',
        ),
        _InfoTile(
          icon: Icons.business_rounded,
          title: 'Proveedor/contexto operativo',
          subtitle:
              'Visible por mision: proveedor, aeronave, FBO y contacto ops.',
        ),
      ],
    );
  }
}

class _DocumentsView extends StatelessWidget {
  const _DocumentsView({required this.documents, required this.onUpload});

  final List<CrewDocument> documents;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionCard(
          title: 'Subir certificado, licencia o PDF',
          subtitle: 'Los documentos quedan pendientes de revision admin.',
          icon: Icons.upload_file_rounded,
          button: 'Subir archivo',
          onPressed: onUpload,
        ),
        const SizedBox(height: 14),
        ...documents.map(
          (item) => _InfoTile(
            icon: Icons.description_rounded,
            title: item.title,
            subtitle: '${item.status} | ${item.expiration}',
          ),
        ),
      ],
    );
  }
}

class _IncidentsView extends StatelessWidget {
  const _IncidentsView({
    required this.assignments,
    required this.incidents,
    required this.onCreate,
  });

  final List<CrewAssignment> assignments;
  final List<CrewIncident> incidents;
  final ValueChanged<CrewAssignment> onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionCard(
          title: 'Crear incidencia operativa',
          subtitle:
              assignments.isEmpty
                  ? 'Necesitas una mision asignada para levantar incidencia.'
                  : 'Registra retrasos, catering, documento, FBO o servicio.',
          icon: Icons.add_alert_rounded,
          button: 'Nueva incidencia',
          onPressed:
              assignments.isEmpty ? () {} : () => onCreate(assignments.first),
        ),
        const SizedBox(height: 14),
        ...incidents.map(
          (item) => _InfoTile(
            icon: Icons.report_gmailerrorred_rounded,
            title: item.title,
            subtitle: '${item.assignment} | ${item.status} | ${item.evidence}',
          ),
        ),
      ],
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({required this.assignments});

  final List<CrewAssignment> assignments;

  @override
  Widget build(BuildContext context) {
    return Column(
      children:
          assignments
              .where((item) => item.status == 'Finalizada')
              .map((item) => _AssignmentCard(item: item))
              .toList(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _InfoTile(
          icon: Icons.notifications_active_rounded,
          title: 'Notificaciones',
          subtitle: 'Nueva mision, cambio de horario, briefing e incidencia.',
        ),
        _InfoTile(
          icon: Icons.sync_rounded,
          title: 'Sincronizacion admin',
          subtitle: 'Asignaciones y respuestas usan canal en vivo y API.',
        ),
        _InfoTile(
          icon: Icons.security_rounded,
          title: 'Validacion movil',
          subtitle: 'Camara, archivos, OCR, rostro y QR habilitados.',
        ),
      ],
    );
  }
}
