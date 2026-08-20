part of 'pantalla_espacio_sobrecargo.dart';

class CrewOperationView extends StatefulWidget {
  const CrewOperationView({super.key, required this.assignment});
  final CrewAssignment assignment;

  @override
  State<CrewOperationView> createState() => _CrewOperationViewState();
}

class _CrewOperationViewState extends State<CrewOperationView> {
  final ApiClient _api = ApiClient.instance;
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic> _workflow = const {};
  bool _loading = true;
  bool _saving = false;
  String _error = '';

  List<Map<String, dynamic>> _list(dynamic value) =>
      value is List
          ? value
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final response = await _api.getCrewOperationWorkflow(
        widget.assignment.resolvedOperationId,
      );
      final source =
          response['data'] is Map
              ? Map<String, dynamic>.from(response['data'])
              : response;
      if (mounted) setState(() => _workflow = source);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runAction(Map<String, dynamic> action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final type = '${action['type'] ?? ''}';
      final operationId = widget.assignment.resolvedOperationId;
      if (type == 'checkin') {
        await _api.updateCrewOperationStep(
          assignmentId: operationId,
          step: 'checkin',
        );
      } else if (type == 'cabin_ready') {
        await _api.updateCrewOperationStep(
          assignmentId: operationId,
          step: 'cabin_ready',
        );
      } else if (type == 'passengers_ready') {
        await _api.updateCrewOperationStep(
          assignmentId: operationId,
          step: 'passengers_ready',
        );
      } else if (type == 'transition') {
        await _api.updateCrewOperationStep(
          assignmentId: operationId,
          step: '${action['status']}',
        );
      } else if (type == 'submit_report') {
        await _showReport();
        return;
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editItem(
    Map<String, dynamic> checklist,
    Map<String, dynamic> item,
  ) async {
    final notes = TextEditingController(text: '${item['notes'] ?? ''}');
    var status = '${item['status'] ?? 'pending'}';
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setSheetState) => Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    MediaQuery.viewInsetsOf(context).bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${item['label'] ?? 'Elemento'}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if ('${item['description'] ?? ''}'.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('${item['description']}'),
                        ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        items: const [
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Pendiente'),
                          ),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Text('Completado'),
                          ),
                          DropdownMenuItem(
                            value: 'not_applicable',
                            child: Text('No aplica'),
                          ),
                          DropdownMenuItem(
                            value: 'failed',
                            child: Text('Falla'),
                          ),
                        ],
                        onChanged:
                            (value) =>
                                setSheetState(() => status = value ?? status),
                        decoration: const InputDecoration(labelText: 'Estado'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notes,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Notas'),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed:
                            () => Navigator.pop(context, {
                              'status': status,
                              'notes': notes.text,
                            }),
                        child: const Text('Guardar cambios'),
                      ),
                    ],
                  ),
                ),
          ),
    );
    notes.dispose();
    if (result == null) return;
    setState(() => _saving = true);
    try {
      await _api.updateCrewChecklistItem(
        operationId: widget.assignment.resolvedOperationId,
        checklistType: '${checklist['type']}',
        itemId: '${item['id']}',
        status: result['status']!,
        notes: result['notes'] ?? '',
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickEvidence(
    Map<String, dynamic> checklist,
    Map<String, dynamic> item,
    ImageSource source,
  ) async {
    if (_saving) return;
    final picked = await _picker.pickImage(source: source, imageQuality: 88);
    if (picked == null) return;
    if (!mounted) return;
    final decision = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Vista previa de evidencia'),
            content: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                File(picked.path),
                fit: BoxFit.contain,
                errorBuilder:
                    (_, _, _) => const SizedBox(
                      height: 180,
                      child: Center(
                        child: Text('No se pudo mostrar la fotografía.'),
                      ),
                    ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('Eliminar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'replace'),
                child: const Text('Reemplazar'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, 'upload'),
                icon: const Icon(Icons.cloud_upload_rounded),
                label: const Text('Guardar fotografía'),
              ),
            ],
          ),
    );
    if (decision == 'replace') {
      await _pickEvidence(checklist, item, source);
      return;
    }
    if (decision != 'upload' || _saving) return;
    setState(() => _saving = true);
    _showEvidenceMessage('Subiendo fotografía...');
    try {
      await _api.uploadCrewChecklistEvidence(
        operationId: widget.assignment.resolvedOperationId,
        checklistType: '${checklist['type']}',
        itemId: '${item['id']}',
        file: File(picked.path),
      );
      await _load();
      _showEvidenceMessage('Fotografía registrada correctamente.');
    } catch (error) {
      _showEvidenceMessage(
        'Error al subir la fotografía. Intenta nuevamente. $error',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showEvidenceMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _flightSummaryCard() {
    final assignment = widget.assignment;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tu próximo vuelo',
              style: TextStyle(
                color: Color(0xFFB7791F),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              assignment.route,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              assignment.aircraft,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(height: 28),
            _summaryLine(
              Icons.calendar_today_rounded,
              'Fecha',
              _compactCrewDate(assignment.date),
            ),
            _summaryLine(
              Icons.schedule_rounded,
              'Presentación',
              assignment.showTime,
            ),
            _summaryLine(
              Icons.groups_rounded,
              'Pasajeros',
              '${assignment.passengers}',
            ),
            if (assignment.origin.isNotEmpty)
              _summaryLine(
                Icons.flight_takeoff_rounded,
                'Salida',
                assignment.origin,
              ),
            if (assignment.destination.isNotEmpty)
              _summaryLine(
                Icons.flight_land_rounded,
                'Llegada',
                assignment.destination,
              ),
            _summaryLine(Icons.verified_rounded, 'Estado', assignment.status),
            if (assignment.code.trim().isNotEmpty && assignment.code != 'OPS')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Folio: ${assignment.code}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xFF385A72)),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w800)),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  String _friendlyActionLabel(Map<String, dynamic> action) {
    final type = '${action['type'] ?? ''}'.toLowerCase();
    final status = '${action['status'] ?? ''}'.toLowerCase();
    if (type == 'checkin') return 'Confirmar llegada al aeropuerto';
    if (type == 'cabin_ready') return 'Confirmar cabina preparada';
    if (type == 'passengers_ready') return 'Confirmar pasajeros a bordo';
    if (type == 'submit_report') return 'Enviar reporte final';
    if (status.contains('service_started')) return 'Iniciar servicio de vuelo';
    if (status.contains('service_final')) return 'Completar cierre';
    final label = '${action['label'] ?? ''}'.trim();
    if (label.toLowerCase().contains('transition') ||
        label.toLowerCase().contains('execute')) {
      return 'Continuar con mi vuelo';
    }
    return label.isEmpty ? 'Continuar con mi vuelo' : _naturalizeText(label);
  }

  IconData _friendlyActionIcon(Map<String, dynamic> action) {
    final type = '${action['type'] ?? ''}'.toLowerCase();
    if (type == 'checkin') return Icons.location_on_rounded;
    if (type == 'cabin_ready') return Icons.airline_seat_recline_normal_rounded;
    if (type == 'passengers_ready') return Icons.groups_rounded;
    if (type == 'submit_report') return Icons.send_rounded;
    return Icons.arrow_forward_rounded;
  }

  String _friendlyChecklistTitle(String type) {
    switch (type.trim().toLowerCase()) {
      case 'preparation':
        return 'Preparación de cabina';
      case 'preflight':
        return 'Antes del vuelo';
      case 'postflight':
        return 'Después del vuelo';
      default:
        return 'Tareas del vuelo';
    }
  }

  String _friendlyEventTitle(Map<String, dynamic> event) {
    final value = '${event['title'] ?? event['status'] ?? ''}';
    final normalized = value.toLowerCase().replaceAll('_', ' ');
    if (normalized.contains('checkin') || normalized.contains('enroute')) {
      return 'Llegué al aeropuerto';
    }
    if (normalized.contains('cabin') || normalized.contains('cabina')) {
      return 'Cabina preparada';
    }
    if (normalized.contains('passenger') || normalized.contains('pasaj')) {
      return 'Pasajeros a bordo';
    }
    if (normalized.contains('service started') ||
        normalized.contains('active')) {
      return 'Servicio de vuelo iniciado';
    }
    if (normalized.contains('completed') || normalized.contains('final')) {
      return 'Vuelo finalizado';
    }
    return _naturalizeText(value);
  }

  String _naturalizeText(String value) {
    final cleaned = value.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return 'Actualización del vuelo';
    return '${cleaned[0].toUpperCase()}${cleaned.substring(1)}';
  }

  String _evidenceUrl(Map<String, dynamic> evidence) {
    final raw =
        '${evidence['url'] ?? evidence['path'] ?? evidence['file_url'] ?? evidence['file_path'] ?? ''}'
            .trim();
    if (raw.isEmpty) return '';
    final parsed = Uri.tryParse(raw);
    if (parsed != null && parsed.hasScheme) return raw;
    final origin = _api.backendOrigin;
    if (origin.isEmpty) return '';
    return raw.startsWith('/') ? '$origin$raw' : '$origin/$raw';
  }

  Future<void> _showSavedEvidence(
    String url,
    Map<String, dynamic> evidence,
    String task,
  ) {
    final date =
        '${evidence['created_at'] ?? evidence['uploaded_at'] ?? ''}'.trim();
    return showDialog<void>(
      context: context,
      builder:
          (context) => Dialog(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      task,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (date.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(date),
                      ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: InteractiveViewer(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder:
                              (_, _, _) => const Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'No pudimos mostrar esta fotografía.',
                                ),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _showReport() async {
    final existing =
        _workflow['final_report'] is Map
            ? Map<String, dynamic>.from(_workflow['final_report'])
            : const <String, dynamic>{};
    final notes = TextEditingController(
      text: '${existing['general_notes'] ?? ''}',
    );
    final cabin = TextEditingController(
      text: '${existing['cabin_condition'] ?? ''}',
    );
    final catering = TextEditingController(
      text: '${existing['catering_condition'] ?? ''}',
    );
    final passengers = TextEditingController(
      text: '${existing['passenger_observations'] ?? ''}',
    );
    final forgotten = TextEditingController(
      text: '${existing['forgotten_items'] ?? ''}',
    );
    final damages = TextEditingController(text: '${existing['damages'] ?? ''}');
    var rating = int.tryParse('${existing['service_rating'] ?? 5}') ?? 5;
    var cleaning = existing['cleaning_required'] == true;
    var restocking = existing['restocking_required'] == true;
    final report = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(
                    existing.isEmpty
                        ? 'Reporte final'
                        : 'Reporte final enviado',
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: rating,
                          decoration: const InputDecoration(
                            labelText: 'Calificación',
                          ),
                          items:
                              [1, 2, 3, 4, 5]
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text('$value'),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              existing.isNotEmpty
                                  ? null
                                  : (value) => setDialogState(
                                    () => rating = value ?? rating,
                                  ),
                        ),
                        TextField(
                          controller: cabin,
                          enabled: existing.isEmpty,
                          decoration: const InputDecoration(
                            labelText: 'Condición de cabina *',
                          ),
                        ),
                        TextField(
                          controller: catering,
                          enabled: existing.isEmpty,
                          decoration: const InputDecoration(
                            labelText: 'Condición de catering *',
                          ),
                        ),
                        TextField(
                          controller: notes,
                          enabled: existing.isEmpty,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Notas generales',
                          ),
                        ),
                        TextField(
                          controller: passengers,
                          enabled: existing.isEmpty,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Observaciones de pasajeros',
                          ),
                        ),
                        TextField(
                          controller: forgotten,
                          enabled: existing.isEmpty,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Objetos olvidados',
                          ),
                        ),
                        TextField(
                          controller: damages,
                          enabled: existing.isEmpty,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Daños detectados',
                          ),
                        ),
                        CheckboxListTile(
                          value: cleaning,
                          onChanged:
                              existing.isNotEmpty
                                  ? null
                                  : (value) => setDialogState(
                                    () => cleaning = value == true,
                                  ),
                          title: const Text('Requiere limpieza'),
                        ),
                        CheckboxListTile(
                          value: restocking,
                          onChanged:
                              existing.isNotEmpty
                                  ? null
                                  : (value) => setDialogState(
                                    () => restocking = value == true,
                                  ),
                          title: const Text('Requiere reposición'),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                    if (existing.isEmpty)
                      FilledButton(
                        onPressed: () {
                          if (cabin.text.trim().isEmpty ||
                              catering.text.trim().isEmpty) {
                            return;
                          }
                          Navigator.pop(context, {
                            'service_rating': rating,
                            'cabin_condition': cabin.text.trim(),
                            'catering_condition': catering.text.trim(),
                            'cleaning_required': cleaning,
                            'restocking_required': restocking,
                            'general_notes': notes.text.trim(),
                            'passenger_observations': passengers.text.trim(),
                            'forgotten_items': forgotten.text.trim(),
                            'damages': damages.text.trim(),
                          });
                        },
                        child: const Text('Enviar'),
                      ),
                  ],
                ),
          ),
    );
    notes.dispose();
    cabin.dispose();
    catering.dispose();
    passengers.dispose();
    forgotten.dispose();
    damages.dispose();
    if (report == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    try {
      await _api.submitCrewFinalReport(
        operationId: widget.assignment.resolvedOperationId,
        report: report,
      );
      await _load();
      _showEvidenceMessage('Operación enviada correctamente.');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = _list(_workflow['allowed_actions']);
    final checklists = _list(_workflow['checklists']);
    final tracking = _list(_workflow['tracking_events']);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi vuelo')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            if (_error.isNotEmpty)
              _InfoTile(
                icon: Icons.cloud_off,
                title: 'No pudimos cargar las tareas del vuelo',
                subtitle:
                    'Revisa tu conexión y desliza hacia abajo para intentar de nuevo.',
              ),
            if (_workflow.isNotEmpty) ...[
              _flightSummaryCard(),
              const SizedBox(height: 16),
              Text(
                '¿Qué debes hacer ahora?',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (actions.isEmpty)
                const _InfoTile(
                  icon: Icons.task_alt_rounded,
                  title: 'No tienes acciones pendientes',
                  subtitle:
                      'El siguiente paso aparecerá aquí cuando esté disponible.',
                ),
              ...actions.map(
                (action) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _runAction(action),
                    icon: Icon(_friendlyActionIcon(action)),
                    label: Text(_friendlyActionLabel(action)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tareas de tu vuelo',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (checklists.isEmpty)
                const _InfoTile(
                  icon: Icons.lock_clock_rounded,
                  title: 'Aún no hay tareas disponibles',
                  subtitle: 'Las tareas aparecerán conforme avance tu vuelo.',
                ),
              ...checklists.map(_checklistCard),
              if (tracking.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Tu progreso',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Text('Seguimiento del vuelo'),
                ),
                const SizedBox(height: 6),
                ...tracking.map(
                  (event) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF16845B),
                    ),
                    title: Text(_friendlyEventTitle(event)),
                    subtitle:
                        '${event['created_at'] ?? ''}'.trim().isEmpty
                            ? null
                            : Text('${event['created_at']}'),
                  ),
                ),
              ],
              if (_workflow['final_report'] is Map) ...[
                const SizedBox(height: 12),
                Text(
                  'Cierre del vuelo',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _showReport,
                  icon: const Icon(Icons.description_rounded),
                  label: const Text('Consultar reporte final'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _checklistCard(Map<String, dynamic> checklist) {
    final items = _list(checklist['items']);
    final completed =
        items
            .where(
              (item) =>
                  ['completed', 'not_applicable'].contains(item['status']),
            )
            .length;
    return Card(
      child: ExpansionTile(
        title: Text(
          _friendlyChecklistTitle('${checklist['type'] ?? ''}'),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text('$completed de ${items.length} tareas completadas'),
        children:
            items.map((item) {
              final evidence = _list(item['evidence_files']);
              return _checklistItemCard(checklist, item, evidence);
            }).toList(),
      ),
    );
  }

  Widget _checklistItemCard(
    Map<String, dynamic> checklist,
    Map<String, dynamic> item,
    List<Map<String, dynamic>> evidence,
  ) {
    final completed = item['status'] == 'completed';
    final failed = item['status'] == 'failed';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE1E7ED)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    completed
                        ? Icons.check_circle_rounded
                        : failed
                        ? Icons.error_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color:
                        completed
                            ? const Color(0xFF16845B)
                            : failed
                            ? Colors.red
                            : Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['label'] ?? item['code'] ?? 'Tarea'}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        if ('${item['description'] ?? ''}'.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('${item['description']}'),
                          ),
                        if ('${item['notes'] ?? ''}'.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('Nota: ${item['notes']}'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                completed
                    ? 'Completado'
                    : failed
                    ? 'Requiere atención'
                    : 'Pendiente',
                style: TextStyle(
                  color:
                      completed
                          ? const Color(0xFF16845B)
                          : failed
                          ? Colors.red
                          : const Color(0xFF6B7280),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _saving ? null : () => _editItem(checklist, item),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: Text(completed ? 'Editar tarea' : 'Completar tarea'),
                  ),
                  TextButton.icon(
                    onPressed:
                        _saving ? null : () => _editItem(checklist, item),
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('Agregar nota'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Evidencia fotográfica',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _saving
                            ? null
                            : () => _pickEvidence(
                              checklist,
                              item,
                              ImageSource.camera,
                            ),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Tomar foto'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _saving
                            ? null
                            : () => _pickEvidence(
                              checklist,
                              item,
                              ImageSource.gallery,
                            ),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Elegir de galería'),
                  ),
                ],
              ),
              if (evidence.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Fotos registradas',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: evidence.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final entry = evidence[index];
                      final url = _evidenceUrl(entry);
                      return InkWell(
                        onTap:
                            url.isEmpty
                                ? null
                                : () => _showSavedEvidence(
                                  url,
                                  entry,
                                  '${item['label'] ?? 'Tarea del vuelo'}',
                                ),
                        borderRadius: BorderRadius.circular(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 76,
                            color: const Color(0xFFE8EEF3),
                            child:
                                url.isEmpty
                                    ? const Icon(Icons.image_rounded)
                                    : Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (_, _, _) => const Icon(
                                            Icons.broken_image_outlined,
                                          ),
                                    ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
