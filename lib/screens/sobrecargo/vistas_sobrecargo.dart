part of 'pantalla_espacio_sobrecargo.dart';

class _DashboardView extends StatelessWidget {
  const _DashboardView({
    required this.assignments,
    required this.incidents,
    required this.documents,
    required this.onScan,
    required this.onOpenAvailability,
    required this.onOpenDocuments,
    required this.onOpenIncidents,
  });

  final List<CrewAssignment> assignments;
  final List<CrewIncident> incidents;
  final List<CrewDocument> documents;
  final VoidCallback onScan;
  final VoidCallback onOpenAvailability;
  final VoidCallback onOpenDocuments;
  final VoidCallback onOpenIncidents;

  @override
  Widget build(BuildContext context) {
    final active =
        assignments.where((item) => item.status != 'Finalizada').length;
    final expiredDocs =
        documents.where((item) => item.status.contains('Vence')).length;
    final pendingAssignments =
        assignments.where((item) => item.canRespondToAssignment).length;
    final openIncidents =
        incidents.where((item) => !item.status.contains('Cerr')).length;
    final readiness = _readinessScore(
      active: active,
      expiredDocs: expiredDocs,
      openIncidents: openIncidents,
      pendingAssignments: pendingAssignments,
    );

    return Column(
      children: [
        _OperationalStrip(
          title: 'Briefing de cabina',
          subtitle:
              'Asignaciones, documentos e incidencias sincronizados para operacion segura.',
          status: active > 0 ? 'Operacion activa' : 'Sin misiones activas',
        ),
        const SizedBox(height: 14),
        _ReadinessCard(
          score: readiness,
          pendingAssignments: pendingAssignments,
          expiredDocs: expiredDocs,
          openIncidents: openIncidents,
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
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _QuickActionChip(
              icon: Icons.event_available_rounded,
              label: 'Disponibilidad',
              onTap: onOpenAvailability,
            ),
            _QuickActionChip(
              icon: Icons.folder_copy_rounded,
              label: 'Documentos',
              onTap: onOpenDocuments,
            ),
            _QuickActionChip(
              icon: Icons.report_problem_rounded,
              label: 'Incidencias',
              onTap: onOpenIncidents,
            ),
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

  int _readinessScore({
    required int active,
    required int expiredDocs,
    required int openIncidents,
    required int pendingAssignments,
  }) {
    var score = 100;
    score -= expiredDocs * 18;
    score -= openIncidents * 12;
    score -= pendingAssignments * 10;
    if (active == 0) score -= 5;
    return score.clamp(0, 100);
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({
    required this.score,
    required this.pendingAssignments,
    required this.expiredDocs,
    required this.openIncidents,
  });

  final int score;
  final int pendingAssignments;
  final int expiredDocs;
  final int openIncidents;

  @override
  Widget build(BuildContext context) {
    final label =
        score >= 85
            ? 'Listo para operar'
            : score >= 65
            ? 'Atencion requerida'
            : 'Riesgo operativo';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration().copyWith(
        gradient: const LinearGradient(
          colors: [Color(0xFF07121D), Color(0xFF173B55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$score%',
                style: const TextStyle(
                  color: Color(0xFFE0B86E),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFE0B86E)),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DarkAlertPill(label: '$pendingAssignments por confirmar'),
              _DarkAlertPill(label: '$expiredDocs docs alerta'),
              _DarkAlertPill(label: '$openIncidents incidencias'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DarkAlertPill extends StatelessWidget {
  const _DarkAlertPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: const Color(0xFF0E2338)),
      label: Text(label),
      labelStyle: const TextStyle(fontWeight: FontWeight.w900),
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFE5EAF0)),
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
    required this.onAdvance,
    required this.onAccept,
  });

  final DateTime selectedDate;
  final List<CrewAssignment> assignments;
  final List<CrewBlock> blocks;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onBlock;
  final void Function(CrewAssignment, CrewMissionAction) onAdvance;
  final ValueChanged<CrewAssignment> onAccept;

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
        ...dayItems.map((item) {
          final nextAction = item.nextAction;
          return _AssignmentCard(
            item: item,
            actions:
                item.canRespondToAssignment
                    ? [
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
        }),
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
  const _ProfileView({
    required this.form,
    required this.onChanged,
    required this.onSave,
  });

  final Map<String, dynamic> form;
  final void Function(String, dynamic) onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _InfoTile(
          icon: Icons.person_pin_rounded,
          title: 'Perfil de vuelo',
          subtitle: 'Edita base, idiomas, experiencia y cobertura operativa.',
        ),
        _FormPanel(
          title: 'Datos operativos',
          children: [
            _TextFormLine(
              label: 'Nombre',
              value: form['name']?.toString() ?? '',
              onChanged: (value) => onChanged('name', value),
            ),
            _TextFormLine(
              label: 'Base',
              value: form['base']?.toString() ?? '',
              onChanged: (value) => onChanged('base', value),
            ),
            _TextFormLine(
              label: 'Idiomas',
              value: form['languages']?.toString() ?? '',
              onChanged: (value) => onChanged('languages', value),
            ),
            _TextFormLine(
              label: 'Experiencia',
              value: form['experience']?.toString() ?? '',
              onChanged: (value) => onChanged('experience', value),
              maxLines: 3,
            ),
            _TextFormLine(
              label: 'Cobertura',
              value: form['coverage']?.toString() ?? '',
              onChanged: (value) => onChanged('coverage', value),
            ),
            DropdownButtonFormField<String>(
              value: form['profileState']?.toString() ?? 'Pendiente',
              decoration: const InputDecoration(labelText: 'Estado perfil'),
              items:
                  const ['Pendiente', 'Validado', 'En revision', 'Rechazado']
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
              onChanged: (value) => onChanged('profileState', value ?? ''),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Guardar perfil'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DocumentsView extends StatelessWidget {
  const _DocumentsView({
    required this.documents,
    required this.onUpload,
    required this.onCreate,
    required this.onStatusChanged,
  });

  final List<CrewDocument> documents;
  final VoidCallback onUpload;
  final void Function(CrewDocument, File?) onCreate;
  final void Function(CrewDocument, String) onStatusChanged;

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
        _DocumentComposer(onCreate: onCreate),
        const SizedBox(height: 14),
        ...documents.map(
          (item) => _DocumentTile(
            document: item,
            onStatusChanged: (status) => onStatusChanged(item, status),
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
    required this.onAddEvidence,
    required this.onAddComment,
    required this.onMarkAttended,
    required this.onEscalate,
  });

  final List<CrewAssignment> assignments;
  final List<CrewIncident> incidents;
  final ValueChanged<CrewAssignment> onCreate;
  final ValueChanged<CrewIncident> onAddEvidence;
  final ValueChanged<CrewIncident> onAddComment;
  final ValueChanged<CrewIncident> onMarkAttended;
  final ValueChanged<CrewIncident> onEscalate;

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
          (item) => _IncidentTile(
            incident: item,
            onAddEvidence: () => onAddEvidence(item),
            onAddComment: () => onAddComment(item),
            onMarkAttended: () => onMarkAttended(item),
            onEscalate: () => onEscalate(item),
          ),
        ),
      ],
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({required this.assignments, required this.incidents});

  final List<CrewAssignment> assignments;
  final List<CrewIncident> incidents;

  @override
  Widget build(BuildContext context) {
    final completed =
        assignments.where((item) => item.status == 'Finalizada').toList();
    return Column(
      children: [
        _MetricGrid(
          metrics: [
            _Metric('Vuelos completados', '${completed.length}', Icons.flight),
            _Metric(
              'Horas estimadas',
              '${completed.length * 4} h',
              Icons.timer,
            ),
            _Metric(
              'Rating',
              completed.isEmpty ? 'Sin dato' : '4.9',
              Icons.star,
            ),
            _Metric('Incidencias', '${incidents.length}', Icons.report),
          ],
        ),
        const SizedBox(height: 14),
        if (completed.isEmpty)
          const _InfoTile(
            icon: Icons.history_rounded,
            title: 'Sin vuelos finalizados',
            subtitle: 'El historial se generara automaticamente.',
          )
        else
          ...completed.map((item) => _AssignmentCard(item: item)),
      ],
    );
  }
}

class _PaymentsView extends StatelessWidget {
  const _PaymentsView({required this.payments, required this.assignments});

  final List<CrewPaymentRecord> payments;
  final List<CrewAssignment> assignments;

  @override
  Widget build(BuildContext context) {
    final completed =
        assignments.where((item) => item.status == 'Finalizada').length;
    return Column(
      children: [
        _MetricGrid(
          metrics: [
            _Metric('Servicios', '$completed', Icons.room_service_rounded),
            const _Metric('Bonos', 'USD 40', Icons.add_card_rounded),
            const _Metric('Penalizaciones', 'USD 0', Icons.gpp_maybe_rounded),
            const _Metric('Corte mensual', 'USD 260', Icons.payments_rounded),
          ],
        ),
        const SizedBox(height: 14),
        ...payments.map(
          (item) => _InfoTile(
            icon: Icons.receipt_long_rounded,
            title: item.concept,
            subtitle: '${item.assignment} | ${item.amount} | ${item.status}',
          ),
        ),
      ],
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView({
    required this.form,
    required this.onChanged,
    required this.onSave,
  });

  final Map<String, dynamic> form;
  final void Function(String, dynamic) onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FormPanel(
          title: 'Preferencias del portal',
          children: [
            SwitchListTile(
              value: form['notifyAssignments'] == true,
              onChanged: (value) => onChanged('notifyAssignments', value),
              title: const Text('Notificar nuevas asignaciones'),
            ),
            SwitchListTile(
              value: form['notifyIncidents'] == true,
              onChanged: (value) => onChanged('notifyIncidents', value),
              title: const Text('Notificar incidencias'),
            ),
            SwitchListTile(
              value: form['notifyScheduleChanges'] == true,
              onChanged: (value) => onChanged('notifyScheduleChanges', value),
              title: const Text('Cambios de agenda'),
            ),
            _TextFormLine(
              label: 'Cobertura personal',
              value: form['personalCoverage']?.toString() ?? '',
              onChanged: (value) => onChanged('personalCoverage', value),
            ),
            DropdownButtonFormField<String>(
              value: form['escalationMode']?.toString() ?? 'Admin primero',
              decoration: const InputDecoration(labelText: 'Escalamiento'),
              items:
                  const [
                        'Admin primero',
                        'Admin y operador',
                        'Solo admin en criticas',
                      ]
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
              onChanged: (value) => onChanged('escalationMode', value ?? ''),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Guardar configuracion'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0E2338),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _TextFormLine extends StatelessWidget {
  const _TextFormLine({
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }
}

class _DocumentComposer extends StatefulWidget {
  const _DocumentComposer({required this.onCreate});

  final void Function(CrewDocument, File?) onCreate;

  @override
  State<_DocumentComposer> createState() => _DocumentComposerState();
}

class _DocumentComposerState extends State<_DocumentComposer> {
  final _name = TextEditingController();
  final _expiration = TextEditingController();
  final _note = TextEditingController();
  String _category = 'Certificacion';
  File? _file;

  @override
  void dispose() {
    _name.dispose();
    _expiration.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FormPanel(
      title: 'Alta documental',
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _category,
          decoration: const InputDecoration(labelText: 'Categoria'),
          items:
              const ['Certificacion', 'Identidad', 'Idioma', 'Experiencia']
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
          onChanged: (value) => setState(() => _category = value ?? _category),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _expiration,
          decoration: const InputDecoration(
            labelText: 'Vencimiento',
            hintText: '2027-12-31',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Nota'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                _file == null
                    ? 'Sin archivo adjunto'
                    : _file!.path.split(Platform.pathSeparator).last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file_rounded),
              label: const Text('Adjuntar'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar documento'),
          ),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => _file = File(path));
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    widget.onCreate(
      CrewDocument(
        title: name,
        status: 'Pendiente',
        expiration:
            _expiration.text.trim().isEmpty
                ? 'Sin vigencia'
                : _expiration.text.trim(),
        category: _category,
        note: _note.text.trim(),
        localPath: _file?.path ?? '',
      ),
      _file,
    );
    _name.clear();
    _expiration.clear();
    _note.clear();
    setState(() => _file = null);
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document, required this.onStatusChanged});

  final CrewDocument document;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    const statusOptions = [
      'Pendiente',
      'En revision',
      'Aprobado',
      'Rechazado',
      'Vence pronto',
      'Vigente',
    ];
    final selectedStatus =
        statusOptions.contains(document.status) ? document.status : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            document.title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${document.category} | Vence: ${document.expiration}',
            style: const TextStyle(color: Color(0xFF5F6975)),
          ),
          if (document.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(document.note),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedStatus,
            decoration: const InputDecoration(labelText: 'Estado'),
            items:
                statusOptions
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
            onChanged: (value) {
              if (value != null) onStatusChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _IncidentTile extends StatelessWidget {
  const _IncidentTile({
    required this.incident,
    required this.onAddEvidence,
    required this.onAddComment,
    required this.onMarkAttended,
    required this.onEscalate,
  });

  final CrewIncident incident;
  final VoidCallback onAddEvidence;
  final VoidCallback onAddComment;
  final VoidCallback onMarkAttended;
  final VoidCallback onEscalate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  incident.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _StatusPill(incident.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${incident.assignment} | Prioridad ${incident.priority} | ${incident.evidence}',
            style: const TextStyle(color: Color(0xFF5F6975)),
          ),
          if (incident.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(incident.description),
          ],
          if (incident.comments.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...incident.comments
                .take(2)
                .map(
                  (comment) => Text(
                    'Comentario: $comment',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onAddEvidence,
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('Evidencia'),
              ),
              OutlinedButton.icon(
                onPressed: onAddComment,
                icon: const Icon(Icons.comment_rounded),
                label: const Text('Comentar'),
              ),
              FilledButton.icon(
                onPressed: onMarkAttended,
                icon: const Icon(Icons.task_alt_rounded),
                label: const Text('Atendida'),
              ),
              OutlinedButton.icon(
                onPressed: onEscalate,
                icon: const Icon(Icons.priority_high_rounded),
                label: const Text('Escalar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
