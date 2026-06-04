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
  });

  final List<CrewAssignment> assignments;
  final ValueChanged<CrewAssignment> onAccept;
  final ValueChanged<CrewAssignment> onReject;

  @override
  Widget build(BuildContext context) {
    return Column(
      children:
          assignments.map((item) {
            return _AssignmentCard(
              item: item,
              actions: [
                OutlinedButton.icon(
                  onPressed: () => onReject(item),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Rechazar'),
                ),
                FilledButton.icon(
                  onPressed: () => onAccept(item),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Confirmar'),
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
          subtitle: 'Registra retrasos, catering, documento, FBO o servicio.',
          icon: Icons.add_alert_rounded,
          button: 'Nueva incidencia',
          onPressed: () => onCreate(assignments.first),
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
