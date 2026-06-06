import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/cliente_api.dart';
import '../shared/widgets/componentes_ui_rol.dart';
import '../shared/widgets/contenedor_espacio_rol.dart';

part 'modelos_sobrecargo.dart';
part 'widgets_sobrecargo.dart';
part 'vistas_sobrecargo.dart';

class CrewWorkspaceScreen extends StatelessWidget {
  const CrewWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleWorkspaceShell(
      branchLabel: 'Operacion',
      roleLabel: 'Sobrecargo',
      title: 'Red Sky Sobrecargo',
      items: [
        RoleWorkspaceItem(
          label: 'Centro Operativo',
          shortLabel: 'Centro',
          icon: Icons.dashboard_customize_rounded,
          screen: CrewPortalScreen(initialTab: CrewPortalTab.dashboard),
        ),
        RoleWorkspaceItem(
          label: 'Misiones',
          shortLabel: 'Misiones',
          icon: Icons.assignment_turned_in_rounded,
          screen: CrewPortalScreen(initialTab: CrewPortalTab.missions),
        ),
        RoleWorkspaceItem(
          label: 'Calendario',
          shortLabel: 'Agenda',
          icon: Icons.calendar_month_rounded,
          screen: CrewPortalScreen(initialTab: CrewPortalTab.calendar),
        ),
        RoleWorkspaceItem(
          label: 'Mi disponibilidad',
          shortLabel: 'Disponible',
          icon: Icons.event_available_rounded,
          screen: CrewPortalScreen(initialTab: CrewPortalTab.availability),
        ),
        RoleWorkspaceItem(
          label: 'Perfil vuelo',
          shortLabel: 'Perfil',
          icon: Icons.badge_rounded,
          screen: CrewPortalScreen(initialTab: CrewPortalTab.profile),
        ),
        RoleWorkspaceItem(
          label: 'Documentos',
          shortLabel: 'Docs',
          icon: Icons.folder_copy_rounded,
          screen: CrewPortalScreen(initialTab: CrewPortalTab.documents),
        ),
        RoleWorkspaceItem(
          label: 'Incidencias',
          shortLabel: 'Incid.',
          icon: Icons.report_problem_rounded,
          screen: CrewPortalScreen(initialTab: CrewPortalTab.incidents),
        ),
        RoleWorkspaceItem(
          label: 'Historial',
          shortLabel: 'Hist.',
          icon: Icons.history_rounded,
          screen: CrewPortalScreen(initialTab: CrewPortalTab.history),
        ),
        RoleWorkspaceItem(
          label: 'Ajustes',
          shortLabel: 'Config',
          icon: Icons.settings_rounded,
          screen: CrewPortalScreen(initialTab: CrewPortalTab.settings),
        ),
      ],
    );
  }
}

enum CrewPortalTab {
  dashboard,
  missions,
  calendar,
  availability,
  profile,
  documents,
  incidents,
  history,
  settings,
}

class CrewPortalScreen extends StatefulWidget {
  const CrewPortalScreen({super.key, required this.initialTab});

  final CrewPortalTab initialTab;

  @override
  State<CrewPortalScreen> createState() => _CrewPortalScreenState();
}

class _CrewPortalScreenState extends State<CrewPortalScreen> {
  final ApiClient _api = ApiClient.instance;
  final ImagePicker _picker = ImagePicker();
  final List<CrewAssignment> _assignments = [...CrewAssignment.demo];
  final List<CrewIncident> _incidents = [...CrewIncident.demo];
  final List<CrewDocument> _documents = [...CrewDocument.demo];
  final List<CrewBlock> _blocks = [];
  final List<CrewAvailabilityRecord> _availability = [];
  List<CrewAvailabilityStatus> _availabilityStatuses = [
    ...CrewAvailabilityStatus.defaults,
  ];
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  bool _isLoading = false;
  bool _availabilityLoading = false;
  String _syncMessage = 'Portal listo con datos locales.';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _refreshPortal();
    _connectLiveAssignments();
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _loadPortal() async {
    setState(() {
      _isLoading = true;
      _syncMessage = 'Sincronizando con admin...';
    });

    try {
      final data = await _api.getCrewPortal();
      final assignments = _asList(data['assignments'] ?? data['misiones']);
      final incidents = _asList(data['incidents'] ?? data['incidencias']);
      final documents = _asList(data['documents'] ?? data['documentos']);

      setState(() {
        if (assignments.isNotEmpty) {
          _assignments
            ..clear()
            ..addAll(assignments.map(CrewAssignment.fromJson));
        }
        if (incidents.isNotEmpty) {
          _incidents
            ..clear()
            ..addAll(incidents.map(CrewIncident.fromJson));
        }
        if (documents.isNotEmpty) {
          _documents
            ..clear()
            ..addAll(documents.map(CrewDocument.fromJson));
        }
        _syncMessage = 'Sincronizado con admin.';
      });
    } catch (_) {
      setState(() {
        _syncMessage =
            'Backend no disponible para sobrecargo; usando datos locales.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshPortal() async {
    await Future.wait([_loadPortal(), _loadAvailability(_selectedDate)]);
  }

  Future<void> _loadAvailability(DateTime focusedDay) async {
    final from = DateTime(focusedDay.year, focusedDay.month);
    final to = DateTime(focusedDay.year, focusedDay.month + 1, 0);
    if (mounted) setState(() => _availabilityLoading = true);

    try {
      final data = await _api.getCrewAvailability(from: from, to: to);
      final records = _asList(data['availability']);
      final statuses = _asList(data['statuses']);
      if (!mounted) return;
      setState(() {
        _availability
          ..clear()
          ..addAll(records.map(CrewAvailabilityRecord.fromJson));
        if (statuses.isNotEmpty) {
          _availabilityStatuses =
              statuses.map(CrewAvailabilityStatus.fromJson).toList();
        }
      });
    } catch (_) {
      if (mounted && widget.initialTab == CrewPortalTab.availability) {
        setState(() {
          _syncMessage = 'No se pudo cargar la disponibilidad del servidor.';
        });
      }
    } finally {
      if (mounted) setState(() => _availabilityLoading = false);
    }
  }

  void _connectLiveAssignments() {
    try {
      final uri = Uri.parse(
        ApiClient.instance.baseUrl,
      ).replace(scheme: 'wss', path: '/ws/crew/assignments');
      _channel = WebSocketChannel.connect(uri);
      _socketSubscription = _channel!.stream.listen(
        (_) {
          if (mounted) {
            setState(() => _syncMessage = 'Asignaciones actualizadas en vivo.');
          }
        },
        onError: (_) {
          if (mounted) {
            setState(() => _syncMessage = 'Canal en vivo pendiente.');
          }
        },
      );
    } catch (_) {
      _syncMessage = 'Canal en vivo pendiente.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: _title,
      subtitle:
          'Misiones, disponibilidad, documentos, incidencias y contexto operativo.',
      roleLabel: 'Sobrecargo',
      body: RefreshIndicator(
        onRefresh: _refreshPortal,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _StatusBanner(message: _syncMessage, isLoading: _isLoading),
            const SizedBox(height: 14),
            _bodyForTab(),
          ],
        ),
      ),
    );
  }

  String get _title {
    switch (widget.initialTab) {
      case CrewPortalTab.dashboard:
        return 'Centro Operativo';
      case CrewPortalTab.missions:
        return 'Misiones activas';
      case CrewPortalTab.calendar:
        return 'Operacion del dia';
      case CrewPortalTab.availability:
        return 'Mi disponibilidad';
      case CrewPortalTab.profile:
        return 'Perfil de vuelo';
      case CrewPortalTab.documents:
        return 'Documentos';
      case CrewPortalTab.incidents:
        return 'Incidencias';
      case CrewPortalTab.history:
        return 'Historial de servicio';
      case CrewPortalTab.settings:
        return 'Ajustes';
    }
  }

  Widget _bodyForTab() {
    switch (widget.initialTab) {
      case CrewPortalTab.dashboard:
        return _DashboardView(
          assignments: _assignments,
          incidents: _incidents,
          documents: _documents,
          onScan: _scanOperationCode,
        );
      case CrewPortalTab.missions:
        return _MissionList(
          assignments: _assignments,
          onAccept: (item) => _respondAssignment(item, 'accepted'),
          onReject: _rejectAssignment,
        );
      case CrewPortalTab.calendar:
        return _CalendarView(
          selectedDate: _selectedDate,
          assignments: _assignments,
          blocks: _blocks,
          onDateSelected: (date) => setState(() => _selectedDate = date),
          onBlock: _createAvailabilityBlock,
        );
      case CrewPortalTab.availability:
        return _AvailabilityView(
          selectedDate: _selectedDate,
          assignments: _assignments,
          records: _availability,
          statuses: _availabilityStatuses,
          isLoading: _availabilityLoading,
          onDateSelected: (date) => setState(() => _selectedDate = date),
          onMonthChanged: _loadAvailability,
          onSave: _saveAvailability,
          onRequestChange: _requestAvailabilityChange,
        );
      case CrewPortalTab.profile:
        return const _ProfileView();
      case CrewPortalTab.documents:
        return _DocumentsView(documents: _documents, onUpload: _uploadDocument);
      case CrewPortalTab.incidents:
        return _IncidentsView(
          assignments: _assignments,
          incidents: _incidents,
          onCreate: _createIncident,
        );
      case CrewPortalTab.history:
        return _HistoryView(assignments: _assignments);
      case CrewPortalTab.settings:
        return const _SettingsView();
    }
  }

  Future<void> _respondAssignment(CrewAssignment item, String status) async {
    final oldStatus = item.status;
    setState(() {
      item.status = status == 'accepted' ? 'Aceptada' : 'Rechazada';
      _syncMessage = 'Enviando respuesta a admin...';
    });
    try {
      await _api.respondCrewAssignment(assignmentId: item.id, status: status);
      setState(() => _syncMessage = 'Admin actualizado.');
    } catch (_) {
      setState(() {
        item.status = oldStatus;
        _syncMessage = 'No se pudo sincronizar la respuesta.';
      });
    }
  }

  Future<void> _rejectAssignment(CrewAssignment item) async {
    final reason = await _TextDialog.show(
      context,
      title: 'Motivo de rechazo',
      label: 'Motivo',
      initial: 'No disponible para esa ventana operativa',
    );
    if (reason == null || reason.trim().isEmpty) return;

    final oldStatus = item.status;
    setState(() {
      item.status = 'Rechazada';
      item.rejectReason = reason.trim();
      _syncMessage = 'Enviando rechazo a admin...';
    });
    try {
      await _api.respondCrewAssignment(
        assignmentId: item.id,
        status: 'rejected',
        reason: reason.trim(),
      );
      setState(() => _syncMessage = 'Rechazo sincronizado con admin.');
    } catch (_) {
      setState(() {
        item.status = oldStatus;
        _syncMessage = 'No se pudo sincronizar el rechazo.';
      });
    }
  }

  Future<void> _createAvailabilityBlock() async {
    final reason = await _TextDialog.show(
      context,
      title: 'Bloquear disponibilidad',
      label: 'Motivo',
      initial: 'Descanso / capacitacion',
    );
    if (reason == null || reason.trim().isEmpty) return;

    final startsAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      0,
    );
    final endsAt = startsAt.add(const Duration(hours: 23, minutes: 59));
    final block = CrewBlock(date: startsAt, reason: reason.trim());

    setState(() {
      _blocks.add(block);
      _syncMessage = 'Sincronizando bloqueo de agenda...';
    });
    try {
      await _api.createCrewAvailabilityBlock(
        startsAt: startsAt,
        endsAt: endsAt,
        reason: reason.trim(),
      );
      setState(() => _syncMessage = 'Disponibilidad actualizada.');
    } catch (_) {
      setState(() => _syncMessage = 'Bloqueo guardado localmente.');
    }
  }

  Future<void> _saveAvailability(
    DateTime date,
    String statusKey,
    String comment,
  ) async {
    setState(() => _syncMessage = 'Guardando disponibilidad...');
    try {
      await _api.saveCrewAvailabilityDay(
        date: date,
        statusKey: statusKey,
        comment: comment,
      );
      await _loadAvailability(date);
      if (mounted) {
        setState(() => _syncMessage = 'Disponibilidad sincronizada con admin.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _syncMessage = 'No se pudo guardar la disponibilidad.');
      }
    }
  }

  Future<void> _requestAvailabilityChange(DateTime date) async {
    final reason = await _TextDialog.show(
      context,
      title: 'Solicitar cambio',
      label: 'Motivo de la solicitud',
      initial: 'Solicito revision de la operacion asignada',
    );
    if (reason == null || reason.trim().isEmpty) return;
    await _saveAvailability(date, 'BLOQUEO_SOLICITADO', reason.trim());
  }

  Future<void> _uploadDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      _documents.insert(
        0,
        CrewDocument(
          title: result!.files.single.name,
          status: 'Pendiente admin',
          expiration: 'Por validar',
        ),
      );
      _syncMessage = 'Documento agregado para revision.';
    });
  }

  Future<void> _createIncident(CrewAssignment assignment) async {
    final description = await _TextDialog.show(
      context,
      title: 'Nueva incidencia',
      label: 'Descripcion',
      initial: 'Detalle operativo',
    );
    if (description == null || description.trim().isEmpty) return;

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    final evidence = picked == null ? null : File(picked.path);
    final incident = CrewIncident(
      title: 'Incidencia ${assignment.code}',
      assignment: assignment.code,
      status: 'Abierta',
      evidence:
          evidence?.path.split(Platform.pathSeparator).last ?? 'Sin evidencia',
    );

    setState(() {
      _incidents.insert(0, incident);
      _syncMessage = 'Sincronizando incidencia...';
    });
    try {
      await _api.createCrewIncident(
        assignmentId: assignment.id,
        title: incident.title,
        description: description.trim(),
        evidence: evidence,
      );
      setState(() => _syncMessage = 'Incidencia enviada a admin.');
    } catch (_) {
      setState(() => _syncMessage = 'Incidencia guardada localmente.');
    }
  }

  Future<void> _scanOperationCode() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: MobileScanner(
            onDetect: (capture) {
              final value = capture.barcodes.first.rawValue;
              if (value == null) return;
              Navigator.pop(context);
              setState(() => _syncMessage = 'Codigo operativo leido: $value');
            },
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
