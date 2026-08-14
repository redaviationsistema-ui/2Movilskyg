import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/cliente_api.dart';
import '../../providers/proveedor_autenticacion.dart';
import '../shared/widgets/componentes_ui_rol.dart';
import '../shared/widgets/contenedor_espacio_rol.dart';

part 'modelos_sobrecargo.dart';
part 'widgets_sobrecargo.dart';
part 'vistas_sobrecargo.dart';

class CrewWorkspaceScreen extends StatelessWidget {
  const CrewWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userName =
        auth.user?.name.trim().isNotEmpty == true
            ? auth.user!.name.trim()
            : auth.displayName.trim();

    return RoleWorkspaceShell(
      branchLabel: userName.isEmpty ? 'Sobrecargo' : userName,
      roleLabel: 'Sobrecargo',
      title: userName.isEmpty ? 'Sobrecargo' : userName,
      items: [
        const RoleWorkspaceItem(
          label: 'Centro Operativo',
          shortLabel: 'Centro',
          icon: Icons.dashboard_customize_rounded,
          screen: CrewPortalScreen(initialTab: CrewPortalTab.dashboard),
        ),
        const RoleWorkspaceItem(
          label: 'Misiones',
          shortLabel: 'Misiones',
          icon: Icons.assignment_turned_in_rounded,
          screen: CrewPortalScreen(initialTab: CrewPortalTab.missions),
        ),

        const RoleWorkspaceItem(
          label: 'Mi disponibilidad',
          shortLabel: 'Disponible',
          icon: Icons.event_available_rounded,
          screen: CrewPortalScreen(initialTab: CrewPortalTab.availability),
        ),

        const RoleWorkspaceItem(
          label: 'Incidencias',
          shortLabel: 'Incid.',
          icon: Icons.report_problem_rounded,
          screen: CrewPortalScreen(initialTab: CrewPortalTab.incidents),
        ),
        const RoleWorkspaceItem(
          label: 'Historial',
          shortLabel: 'Hist.',
          icon: Icons.history_rounded,
          screen: CrewPortalScreen(initialTab: CrewPortalTab.history),
        ),

        const RoleWorkspaceItem(
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
  payments,
  settings,
}

String resolveCrewAssignmentStatusForPayload(Map<String, dynamic> payload) {
  return CrewAssignment.fromJson(payload).status;
}

class CrewPortalScreen extends StatefulWidget {
  const CrewPortalScreen({super.key, required this.initialTab});

  final CrewPortalTab initialTab;

  @override
  State<CrewPortalScreen> createState() => _CrewPortalScreenState();
}

class _CrewPortalScreenState extends State<CrewPortalScreen>
    with WidgetsBindingObserver {
  static const Duration _statusBannerDuration = Duration(seconds: 3);
  static const Duration _autoRefreshInterval = Duration(seconds: 35);
  static const bool _enableCrewDebugLogs = false;

  final ApiClient _api = ApiClient.instance;
  final ImagePicker _picker = ImagePicker();
  final List<CrewAssignment> _assignments = [];
  final List<CrewIncident> _incidents = [];
  final List<CrewDocument> _documents = [];
  final List<CrewPaymentRecord> _payments = [];
  final List<CrewBlock> _blocks = [];
  final List<CrewAvailabilityRecord> _availability = [];
  List<CrewAvailabilityStatus> _availabilityStatuses = [
    ...CrewAvailabilityStatus.defaults,
  ];
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _statusBannerTimer;
  Timer? _autoRefreshTimer;
  bool _isLoading = false;
  bool _availabilityLoading = false;
  String _syncMessage = '';
  String _storedOperationalStatus = '';
  DateTime _selectedDate = DateTime.now();
  final Map<String, dynamic> _profileForm = {
    'name': '',
    'base': '',
    'languages': '',
    'experience': '',
    'coverage': '',
    'profileState': '',
  };
  final Map<String, dynamic> _configForm = {
    'notifyAssignments': true,
    'notifyIncidents': true,
    'notifyScheduleChanges': true,
    'personalCoverage': 'Nacional',
    'escalationMode': 'Admin primero',
  };
  final Map<String, dynamic> _agendaBlockForm = {
    'state': 'NO_DISPONIBLE',
    'blockType': '',
    'reason': '',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPortal();
    unawaited(_connectLiveAssignments());
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      unawaited(_refreshPortal(silent: true));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusBannerTimer?.cancel();
    _autoRefreshTimer?.cancel();
    _closeLiveChannel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_refreshPortal());
  }

  Future<void> _loadPortal({bool silent = false}) async {
    final syncStopwatch = Stopwatch()..start();
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }

    var loadedAnyResource = false;
    final missedResources = <String>[];
    try {
      final dashboardFuture = _api.getCrewDashboard();
      final assignmentsFuture = _api.getCrewAssignments();
      final profileFuture = _api.getCrewProfile();
      final documentsFuture = _api.getCrewDocuments();
      final incidentsFuture = _api.getCrewIncidents(
        operationId: _currentIncidentOperationId,
      );

      Future<Map<String, dynamic>?> captureResource(
        String label,
        Future<Map<String, dynamic>> future,
      ) async {
        try {
          return await future;
        } catch (error) {
          missedResources.add(label);
          if (_enableCrewDebugLogs) {
            debugPrint('[crew-mobile] $label sync failed: $error');
          }
          return null;
        }
      }

      final results = await Future.wait<Map<String, dynamic>?>([
        captureResource('panel', dashboardFuture),
        captureResource('asignaciones', assignmentsFuture),
        captureResource('perfil', profileFuture),
        captureResource('documentos', documentsFuture),
        captureResource('incidencias', incidentsFuture),
      ]);

      final dashboardData = results[0];
      final assignmentsData = results[1];
      final profileData = results[2];
      final documentsData = results[3];
      final incidentsData = results[4];

      _logCrewPayload('dashboard', dashboardData);
      _logCrewPayload('assignments', assignmentsData);
      _logCrewPayload('profile', profileData);
      _logCrewPayload('documents', documentsData);
      _logCrewPayload('incidents', incidentsData);

      if (assignmentsData != null) {
        final source = _payloadSource(assignmentsData);
        final assignments = _pickList(source, const [
          'assignments',
          'asignaciones',
          'operations',
          'operaciones',
          'crew_assignments',
          'missions',
          'misiones',
        ]);
        if (mounted) {
          setState(() {
            _assignments
              ..clear()
              ..addAll(assignments.map(CrewAssignment.fromJson));
          });
        }
        loadedAnyResource = true;
      }

      if (profileData != null) {
        final source = _payloadSource(profileData);
        final profile = _pickMap(source, const ['profile', 'user', 'data']);
        if (mounted) {
          setState(() {
            _mergeProfileData(
              profile,
              _pickMap(profile, const ['preferences']),
            );
          });
        }
        loadedAnyResource = true;
      }

      if (documentsData != null) {
        final source = _payloadSource(documentsData);
        final documents = _pickList(source, const [
          'documents',
          'documentos',
          'data',
          'items',
        ]);
        if (mounted) {
          setState(() {
            _documents
              ..clear()
              ..addAll(documents.map(CrewDocument.fromJson));
          });
        }
        loadedAnyResource = true;
      }

      if (incidentsData != null) {
        final source = _payloadSource(incidentsData);
        final incidents = _pickList(source, const [
          'incidents',
          'incidencias',
          'data',
          'items',
        ]);
        if (mounted) {
          setState(() {
            _incidents
              ..clear()
              ..addAll(_dedupeIncidents(incidents.map(CrewIncident.fromJson)));
          });
        }
        loadedAnyResource = true;
      }

      if (dashboardData != null) {
        final source = _payloadSource(dashboardData);
        final payments = _pickList(source, const [
          'payments',
          'pagos',
          'earnings',
          'commissions',
          'nomina',
        ]);
        final profile = _pickMap(source, const [
          'profile',
          'perfil',
          'crew_profile',
          'sobrecargo',
          'crew',
        ]);
        final preferences = _pickMap(source, const [
          'preferences',
          'preferencias',
          'settings',
          'config',
        ]);
        if (mounted && payments.isNotEmpty) {
          setState(() {
            _payments
              ..clear()
              ..addAll(payments.map(CrewPaymentRecord.fromJson));
          });
        }
        if (mounted) {
          setState(() {
            _mergeProfileData(profile, preferences);
          });
        }
        loadedAnyResource = true;
      }

      if (!loadedAnyResource) {
        final fallback = await _api.getCrewPortal();
        final source = _payloadSource(fallback);
        final assignments = _pickList(source, const [
          'assignments',
          'misiones',
          'missions',
          'crew_assignments',
          'asignaciones',
        ]);
        final incidents = _pickList(source, const [
          'incidents',
          'incidencias',
          'incidentes',
        ]);
        final documents = _pickList(source, const [
          'documents',
          'documentos',
          'files',
          'expediente',
        ]);
        final payments = _pickList(source, const [
          'payments',
          'pagos',
          'earnings',
          'commissions',
          'nomina',
        ]);
        final profile = _pickMap(source, const [
          'profile',
          'perfil',
          'crew_profile',
          'sobrecargo',
          'crew',
        ]);
        final preferences = _pickMap(source, const [
          'preferences',
          'preferencias',
          'settings',
          'config',
        ]);

        if (mounted) {
          setState(() {
            _assignments
              ..clear()
              ..addAll(assignments.map(CrewAssignment.fromJson));
            _incidents
              ..clear()
              ..addAll(_dedupeIncidents(incidents.map(CrewIncident.fromJson)));
            _documents
              ..clear()
              ..addAll(documents.map(CrewDocument.fromJson));
            _payments
              ..clear()
              ..addAll(payments.map(CrewPaymentRecord.fromJson));
          });
        }
        if (mounted) {
          setState(() {
            _mergeProfileData(profile, preferences);
          });
        }
        loadedAnyResource = true;
      }

      if (loadedAnyResource && !silent) {
        _logCrewSnapshot();
        if (missedResources.isNotEmpty) {
          final elapsed = (syncStopwatch.elapsedMilliseconds / 1000)
              .toStringAsFixed(1);
          _showSyncMessage(
            'Sincronizado parcial en ${elapsed}s. Revisa: ${missedResources.join(', ')}.',
          );
        }
      } else if (!silent) {
        _showSyncMessage('No se pudo sincronizar el portal operativo.');
      }
    } catch (_) {
      if (!silent) {
        _showSyncMessage('No se pudo sincronizar el portal operativo.');
      }
    } finally {
      if (!silent && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshPortal({bool silent = false}) async {
    await Future.wait([
      _loadPortal(silent: silent),
      _loadAvailability(_selectedDate, silent: silent),
    ]);
  }

  Future<void> _loadAvailability(
    DateTime focusedDay, {
    bool silent = false,
  }) async {
    final from = DateTime(focusedDay.year, focusedDay.month);
    final to = DateTime(focusedDay.year, focusedDay.month + 1, 0);
    if (!silent && mounted) {
      setState(() => _availabilityLoading = true);
    }

    try {
      final data = await _api.getCrewAvailability(from: from, to: to);
      final source = _payloadSource(data);
      final records = _pickList(source, const [
        'availability',
        'disponibilidad',
        'calendar',
        'calendario',
        'items',
      ]);
      final statuses = _pickList(source, const [
        'statuses',
        'estatuses',
        'catalog',
        'catalogo',
      ]);
      if (!mounted) return;
      setState(() {
        _availability
          ..clear()
          ..addAll(_expandAvailabilityRecords(records));
        if (statuses.isNotEmpty) {
          _availabilityStatuses =
              statuses.map(CrewAvailabilityStatus.fromJson).toList();
        }
      });
    } catch (_) {
      if (mounted && widget.initialTab == CrewPortalTab.availability) {
        _showSyncMessage('No se pudo cargar la disponibilidad del servidor.');
      }
    } finally {
      if (!silent && mounted) {
        setState(() => _availabilityLoading = false);
      }
    }
  }

  Future<void> _connectLiveAssignments() async {
    final origin = ApiClient.instance.backendOrigin;
    final parsedOrigin = Uri.tryParse(origin);
    if (parsedOrigin == null || parsedOrigin.host.isEmpty) {
      _showSyncMessage('Canal en vivo pendiente.');
      return;
    }

    final wsScheme = parsedOrigin.scheme == 'https' ? 'wss' : 'ws';
    final portSegment = parsedOrigin.hasPort ? ':${parsedOrigin.port}' : '';
    final wsUri = Uri.parse(
      '$wsScheme://${parsedOrigin.host}$portSegment/ws/crew/assignments',
    );

    try {
      final socket = await WebSocket.connect(wsUri.toString());
      final channel = IOWebSocketChannel(socket);
      _channel = channel;
      _socketSubscription = channel.stream.listen(
        (_) {
          if (mounted) {
            _showSyncMessage('Asignaciones actualizadas en vivo.');
            unawaited(_refreshPortal());
          }
        },
        onError: (_) {
          _closeLiveChannel();
          _showSyncMessage('Canal en vivo pendiente.');
        },
        onDone: () {
          _closeLiveChannel();
          _showSyncMessage('Canal en vivo pendiente.');
        },
        cancelOnError: true,
      );
    } catch (_) {
      _closeLiveChannel();
      _showSyncMessage('Canal en vivo pendiente.');
    }
  }

  void _closeLiveChannel() {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  String? get _currentIncidentOperationId {
    for (final assignment in _assignments) {
      final operationId = assignment.resolvedOperationId;
      if (operationId.isNotEmpty) return operationId;
    }
    return null;
  }

  String get _resolvedOperationalStatus {
    if (_assignments.any((item) => item.status == 'En servicio')) {
      return 'En vuelo';
    }
    if (_assignments.any((item) => item.status == 'Incidencia')) {
      return 'Incidencia';
    }
    if (_assignments.any((item) {
      return const [
        'Confirmado',
        'Preparacion',
        'En aeropuerto/base',
        'Cabina revisada',
        'Pasajeros recibidos',
      ].contains(item.status);
    })) {
      return 'Asignado';
    }
    if (_storedOperationalStatus.trim().isNotEmpty) {
      return _storedOperationalStatus.trim();
    }
    final today = DateTime.now();
    final todayAvailability =
        _availability.where((item) {
          return item.date.year == today.year &&
              item.date.month == today.month &&
              item.date.day == today.day;
        }).toList();
    if (todayAvailability.any((item) => item.statusKey == 'NO_DISPONIBLE')) {
      return 'No disponible';
    }
    if (todayAvailability.any((item) => item.statusKey == 'DESCANSO')) {
      return 'Descanso';
    }
    if (todayAvailability.any((item) => item.statusKey == 'DISPONIBLE')) {
      return 'Disponible';
    }
    return '';
  }

  String get _resolvedBaseLabel {
    final base = _profileForm['base']?.toString().trim() ?? '';
    if (base.isNotEmpty) return base;
    for (final assignment in _assignments) {
      final origin = assignment.origin.trim();
      if (origin.isNotEmpty) return origin;
    }
    return '';
  }

  List<CrewIncident> _dedupeIncidents(Iterable<CrewIncident> incidents) {
    final seen = <String>{};
    final unique = <CrewIncident>[];
    for (final incident in incidents) {
      final signature = [
        incident.assignment.trim().toLowerCase(),
        incident.title.trim().toLowerCase(),
        incident.priority.trim().toLowerCase(),
        incident.status.trim().toLowerCase(),
        incident.description.trim().toLowerCase(),
        incident.evidence.trim().toLowerCase(),
      ].join('|');
      if (!seen.add(signature)) continue;
      unique.add(incident);
    }
    return unique;
  }

  void _logCrewPayload(String label, Map<String, dynamic>? payload) {
    if (!_enableCrewDebugLogs || payload == null) return;
    final keys = payload.keys.toList();
    debugPrint('[crew-mobile] $label keys=$keys');
    try {
      final preview = jsonEncode(payload);
      debugPrint(
        '[crew-mobile] $label payload=${preview.length > 1200 ? '${preview.substring(0, 1200)}...' : preview}',
      );
    } catch (_) {
      debugPrint('[crew-mobile] $label payload=$payload');
    }
  }

  void _logCrewSnapshot() {
    if (!_enableCrewDebugLogs) return;
    debugPrint(
      '[crew-mobile] snapshot status=$_resolvedOperationalStatus base=$_resolvedBaseLabel profileState=${_profileForm['profileState']} assignments=${_assignments.length} incidents=${_incidents.length} documents=${_documents.length} availability=${_availability.length}',
    );
    if (_assignments.isNotEmpty) {
      final first = _assignments.first;
      debugPrint(
        '[crew-mobile] firstAssignment route=${first.route} status=${first.status} showTime=${first.showTime} origin=${first.origin} pax=${first.passengers}',
      );
    }
  }

  void _showSyncMessage(String message, {bool persist = false}) {
    if (!mounted) return;
    _statusBannerTimer?.cancel();
    setState(() => _syncMessage = message);
    if (persist) return;
    _statusBannerTimer = Timer(_statusBannerDuration, () {
      if (!mounted || _syncMessage != message || _isLoading) return;
      setState(() => _syncMessage = '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final compact = mediaQuery.size.width < 430;

    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler:
            compact
                ? TextScaler.noScaling
                : mediaQuery.textScaler.clamp(maxScaleFactor: 1.0),
      ),
      child: RoleDashboardScaffold(
        title: _title,
        subtitle:
            'Misiones, disponibilidad, documentos, incidencias y contexto operativo.',
        roleLabel: 'Sobrecargo',
        body: RefreshIndicator(
          onRefresh: _refreshPortal,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              compact ? 14 : 18,
              compact ? 14 : 18,
              compact ? 14 : 18,
              compact ? 28 : 36,
            ),
            children: [_bodyForTab()],
          ),
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
      case CrewPortalTab.payments:
        return 'Pagos y comisiones';
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
          currentStatus: _resolvedOperationalStatus,
          baseLabel: _resolvedBaseLabel,
          profileState:
              _profileForm['profileState']?.toString().trim().isNotEmpty == true
                  ? _profileForm['profileState'].toString().trim()
                  : 'Sin validar',
          onScan: _scanOperationCode,
          onOpenMissions: () => _openLocalTab(CrewPortalTab.missions),
          onOpenAvailability: () => _openLocalTab(CrewPortalTab.availability),
          onOpenDocuments: () => _openLocalTab(CrewPortalTab.documents),
          onOpenIncidents: () => _openLocalTab(CrewPortalTab.incidents),
        );
      case CrewPortalTab.missions:
        return _MissionList(
          assignments: _assignments,
          coordinationLabel: _coordinationLabel,
          onAccept: (item) => _respondAssignment(item, 'Confirmado'),
          onReject: _rejectAssignment,
          onRequestChange: _requestAssignmentChange,
          onAdvance: _advanceAssignmentStep,
        );
      case CrewPortalTab.calendar:
        return _CalendarView(
          selectedDate: _selectedDate,
          assignments: _assignments,
          blocks: _blocks,
          blockForm: _agendaBlockForm,
          statuses: _availabilityStatuses,
          coordinationLabel: _coordinationLabel,
          onDateSelected: (date) => setState(() => _selectedDate = date),
          onBlockFormChanged: _updateAgendaBlockField,
          onBlock: _createAvailabilityBlock,
          onAdvance: _advanceAssignmentStep,
          onAccept: (item) => _respondAssignment(item, 'Confirmado'),
        );
      case CrewPortalTab.availability:
        return _AvailabilityView(
          selectedDate: _selectedDate,
          assignments: _assignments,
          records: _availability,
          statuses: _availabilityStatuses,
          baseLabel: _resolvedBaseLabel,
          coverageLabel:
              _profileForm['coverage']?.toString().trim().isNotEmpty == true
                  ? _profileForm['coverage'].toString().trim()
                  : _configForm['personalCoverage']?.toString().trim() ?? '',
          isLoading: _availabilityLoading,
          onDateSelected: (date) => setState(() => _selectedDate = date),
          onMonthChanged: _loadAvailability,
          onSave: _saveAvailability,
          onRequestChange: _requestAvailabilityChange,
        );
      case CrewPortalTab.profile:
        return _ProfileView(
          form: _profileForm,
          onChanged: _updateProfileField,
          onSave: _saveProfile,
        );
      case CrewPortalTab.documents:
        return _DocumentsView(
          documents: _documents,
          onUpload: _uploadDocument,
          onCreate: _createDocumentDetailed,
          onStatusChanged: _updateDocumentStatus,
        );
      case CrewPortalTab.incidents:
        return _IncidentsView(
          assignments: _assignments,
          incidents: _incidents,
          onCreate: _createIncident,
          onAddEvidence: _addIncidentEvidence,
          onAddComment: _addIncidentComment,
          onMarkAttended: _markIncidentAttended,
          onEscalate: _escalateIncident,
        );
      case CrewPortalTab.history:
        return _HistoryView(assignments: _assignments, incidents: _incidents);
      case CrewPortalTab.payments:
        return _PaymentsView(payments: _payments, assignments: _assignments);
      case CrewPortalTab.settings:
        return _SettingsView(
          form: _configForm,
          onChanged: _updateConfigField,
          onSave: _saveConfig,
        );
    }
  }

  void _openLocalTab(CrewPortalTab tab) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CrewPortalScreen(initialTab: tab)),
    );
  }

  Future<void> _respondAssignment(CrewAssignment item, String status) async {
    final oldStatus = item.status;
    setState(() {
      item.status = CrewAssignment.normalizeStatus(status);
    });
    _showSyncMessage('Enviando respuesta a admin...', persist: true);
    try {
      await _submitCrewAssignmentResponse(item, status: status);
      await _loadPortal();
      final refreshed = _assignments
          .where(
            (candidate) =>
                candidate.id == item.id ||
                candidate.operationId == item.operationId,
          )
          .cast<CrewAssignment?>()
          .firstWhere((candidate) => candidate != null, orElse: () => null);
      _showSyncMessage('Admin actualizado.');
    } on ApiException catch (error) {
      setState(() {
        item.status = oldStatus;
      });
      _showSyncMessage(_assignmentResponseErrorMessage(error));
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
    });
    _showSyncMessage('Enviando rechazo a admin...', persist: true);
    try {
      await _submitCrewAssignmentResponse(
        item,
        status: 'Rechazado',
        reason: reason.trim(),
      );
      await _loadPortal();
      _showSyncMessage('Rechazo sincronizado con admin.');
    } catch (_) {
      setState(() {
        item.status = oldStatus;
      });
      _showSyncMessage('No se pudo sincronizar el rechazo.');
    }
  }

  Future<void> _requestAssignmentChange(CrewAssignment item) async {
    final reason = await _TextDialog.show(
      context,
      title: 'Solicitar revision',
      label: 'Comentario para operaciones',
      initial: 'Solicito revision de horario, ruta o condicion operativa',
    );
    if (reason == null || reason.trim().isEmpty) return;

    final oldStatus = item.status;
    setState(() {
      item.status = 'Solicitar revision';
      item.rejectReason = reason.trim();
    });
    _showSyncMessage('Solicitando revision a admin...', persist: true);
    try {
      await _submitCrewAssignmentResponse(
        item,
        status: 'Solicitar revision',
        reason: reason.trim(),
      );
      await _loadPortal();
      _showSyncMessage('Revision enviada a admin.');
    } catch (_) {
      setState(() {
        item.status = oldStatus;
      });
      _showSyncMessage('No se pudo solicitar la revision.');
    }
  }

  Future<void> _advanceAssignmentStep(
    CrewAssignment item,
    CrewMissionAction action,
  ) async {
    final oldStatus = item.status;
    setState(() {
      item.status = action.nextStatus;
    });
    _showSyncMessage(
      'Actualizando ${action.label.toLowerCase()}...',
      persist: true,
    );

    try {
      await _submitCrewOperationStep(item, action);
      await _loadPortal();
      _showSyncMessage('${action.label} sincronizado.');
    } catch (_) {
      setState(() {
        item.status = oldStatus;
      });
      _showSyncMessage('No se pudo avanzar el flujo operativo.');
    }
  }

  Future<void> _submitCrewAssignmentResponse(
    CrewAssignment item, {
    required String status,
    String reason = '',
  }) async {
    final operationId = item.resolvedOperationId;
    if (operationId.isEmpty) {
      throw const ApiException(
        'No se encontró la operación asociada a esta asignación.',
      );
    }

    await _api.respondCrewAssignment(
      operationId: operationId,
      status: status,
      reason: reason,
    );
  }

  Future<void> _submitCrewOperationStep(
    CrewAssignment item,
    CrewMissionAction action,
  ) async {
    ApiException? lastError;

    for (final id in {item.resolvedOperationId, item.id.trim()}) {
      if (id.isEmpty) continue;
      try {
        await _api.updateCrewOperationStep(
          assignmentId: id,
          step: action.step,
          note: action.note,
        );
        return;
      } on ApiException catch (error) {
        lastError = error;
      }
    }

    throw lastError ??
        const ApiException('No se pudo avanzar el flujo operativo.');
  }

  String _assignmentResponseErrorMessage(ApiException error) {
    final backendMessage = error.message.trim();
    if (backendMessage.isEmpty) {
      return 'No se pudo sincronizar la respuesta.';
    }
    return 'No fue posible confirmar disponibilidad.\n\n$backendMessage';
  }

  Future<void> _createAvailabilityBlock() async {
    final state = _agendaBlockForm['state']?.toString().trim() ?? '';
    final blockType = _agendaBlockForm['blockType']?.toString().trim() ?? '';
    final reason = _agendaBlockForm['reason']?.toString().trim() ?? '';
    if (blockType.isEmpty) {
      _showSyncMessage('Selecciona el tipo de bloqueo antes de guardar.');
      return;
    }
    if (reason.isEmpty) {
      _showSyncMessage('Agrega el motivo del bloqueo de agenda.');
      return;
    }

    final startsAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      0,
    );
    final endsAt = startsAt.add(const Duration(hours: 23, minutes: 59));
    final block = CrewBlock(
      date: startsAt,
      state: _availabilityLabel(_normalizeAvailabilityKey(state)),
      blockType: blockType,
      reason: reason,
    );

    setState(() {
      _blocks.add(block);
      _agendaBlockForm['reason'] = '';
      _agendaBlockForm['blockType'] = '';
    });
    _showSyncMessage('Sincronizando bloqueo de agenda...', persist: true);
    try {
      await _api.createCrewAvailabilityBlock(
        startsAt: startsAt,
        endsAt: endsAt,
        reason: '$blockType | $reason',
      );
      _showSyncMessage('Disponibilidad actualizada.');
    } catch (_) {
      _showSyncMessage('Bloqueo guardado localmente.');
    }
  }

  void _updateAgendaBlockField(String key, dynamic value) {
    setState(() => _agendaBlockForm[key] = value);
  }

  String get _coordinationLabel {
    final provider = _assignments
        .map((item) => item.provider.trim())
        .firstWhere((item) => item.isNotEmpty, orElse: () => '');
    return provider.isEmpty ? 'Operaciones' : provider;
  }

  Future<void> _saveAvailability(
    DateTime date,
    String statusKey,
    String comment,
  ) async {
    _showSyncMessage('Guardando disponibilidad...', persist: true);
    try {
      final coverage =
          _profileForm['coverage']?.toString().trim().isNotEmpty == true
              ? _profileForm['coverage'].toString().trim()
              : (_configForm['personalCoverage']?.toString().trim() ?? '');
      await _api.saveCrewAvailabilityDay(
        date: date,
        statusKey: statusKey,
        comment: comment,
        base: _resolvedBaseLabel,
        coverage: coverage,
      );
      try {
        await _api.auditCrewAvailabilityDay(
          date: date,
          statusKey: statusKey,
          comment: comment,
        );
      } catch (_) {
        // La auditoria es best-effort como en web; el guardado principal manda.
      }
      await _loadAvailability(date);
      _showSyncMessage('Disponibilidad sincronizada con admin.');
    } catch (_) {
      _showSyncMessage('No se pudo guardar la disponibilidad.');
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

  void _updateProfileField(String key, dynamic value) {
    setState(() => _profileForm[key] = value);
  }

  Future<void> _saveProfile() async {
    final name = _profileForm['name']?.toString().trim() ?? '';
    final base = _profileForm['base']?.toString().trim() ?? '';
    if (name.isEmpty) {
      _showSyncMessage('Completa tu nombre operativo antes de guardar.');
      return;
    }
    if (base.isEmpty) {
      _showSyncMessage('Completa tu base operativa antes de guardar.');
      return;
    }

    _showSyncMessage('Guardando perfil de vuelo...', persist: true);
    try {
      await _api.post(
        '/sobrecargo/profile',
        body: {
          'name': _profileForm['name'],
          'base': _profileForm['base'],
          'languages': _profileForm['languages'],
          'experience': _profileForm['experience'],
          'coverage': _profileForm['coverage'],
          'profile_state': _profileForm['profileState'],
        },
        authenticated: true,
      );
      _showSyncMessage('Perfil actualizado.');
    } catch (_) {
      _showSyncMessage('Perfil guardado localmente.');
    }
  }

  void _updateConfigField(String key, dynamic value) {
    setState(() => _configForm[key] = value);
  }

  Future<void> _saveConfig() async {
    _showSyncMessage('Guardando preferencias...', persist: true);
    try {
      await _api.post(
        '/sobrecargo/profile',
        body: {
          'preferences': {
            'notify_assignments': _configForm['notifyAssignments'] == true,
            'notify_incidents': _configForm['notifyIncidents'] == true,
            'notify_schedule_changes':
                _configForm['notifyScheduleChanges'] == true,
            'personal_coverage': _configForm['personalCoverage'],
            'escalation_mode': _configForm['escalationMode'],
          },
        },
        authenticated: true,
      );
      _showSyncMessage('Preferencias sincronizadas.');
    } catch (_) {
      _showSyncMessage('Preferencias guardadas localmente.');
    }
  }

  Future<void> _createDocumentDetailed(
    CrewDocument document,
    File? file,
  ) async {
    setState(() {
      _documents.insert(0, document);
    });
    _showSyncMessage('Sincronizando documento...', persist: true);
    try {
      if (file != null) {
        await _api.postMultipart(
          '/sobrecargo/documents',
          authenticated: true,
          fields: {
            'name': document.title,
            'category': document.category,
            'expires_at': document.expiration,
            'note': document.note,
            'status': document.status,
          },
          files: {'document': file},
        );
      } else {
        await _api.post(
          '/sobrecargo/documents',
          authenticated: true,
          body: {
            'name': document.title,
            'category': document.category,
            'expires_at': document.expiration,
            'note': document.note,
            'status': document.status,
          },
        );
      }
      _showSyncMessage('Documento enviado a admin.');
    } catch (_) {
      _showSyncMessage('Documento guardado localmente.');
    }
  }

  void _updateDocumentStatus(CrewDocument document, String status) {
    setState(() {
      document.status = status;
    });
    _showSyncMessage('Estado documental actualizado localmente.');
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
          status: 'Pendiente',
          expiration: 'Por validar',
          category: 'Certificacion',
          localPath: path,
        ),
      );
    });
    _showSyncMessage('Documento agregado para revision.');
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
    });
    _showSyncMessage('Sincronizando incidencia...', persist: true);
    try {
      await _api.createCrewIncident(
        assignmentId: assignment.resolvedOperationId,
        title: incident.title,
        description: description.trim(),
        evidence: evidence,
      );
      _showSyncMessage('Incidencia enviada a admin.');
    } catch (_) {
      _showSyncMessage('Incidencia guardada localmente.');
    }
  }

  Future<void> _addIncidentEvidence(CrewIncident incident) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked == null) return;
    setState(() {
      incident.evidence = picked.path.split(Platform.pathSeparator).last;
    });
    _showSyncMessage('Evidencia agregada a incidencia.');
  }

  Future<void> _addIncidentComment(CrewIncident incident) async {
    final comment = await _TextDialog.show(
      context,
      title: 'Agregar comentario',
      label: 'Comentario',
      initial: 'Actualizacion operativa',
    );
    if (comment == null || comment.trim().isEmpty) return;
    setState(() {
      incident.comments = [comment.trim(), ...incident.comments];
    });
    _showSyncMessage('Comentario agregado.');
  }

  void _markIncidentAttended(CrewIncident incident) {
    setState(() {
      incident.status = 'Atendida';
    });
    _showSyncMessage('Incidencia marcada como atendida.');
  }

  Future<void> _escalateIncident(CrewIncident incident) async {
    setState(() {
      incident.status = 'Escalada';
      incident.priority = 'Alta';
    });
    _showSyncMessage('Escalando incidencia a admin...', persist: true);
    try {
      await _api.post(
        '/sobrecargo/incidents/escalate',
        authenticated: true,
        body: {
          'title': incident.title,
          'assignment': incident.assignment,
          'comment': 'Escalada desde app movil de sobrecargo.',
        },
      );
      _showSyncMessage('Incidencia escalada.');
    } catch (_) {
      _showSyncMessage('Incidencia escalada localmente.');
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
              _showSyncMessage('Codigo operativo leido: $value');
            },
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is Map && value['data'] is List) {
      return _asList(value['data']);
    }
    if (value is! List) return [];
    return value.whereType<Map>().map((item) {
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  Map<String, dynamic> _payloadSource(Map<String, dynamic> data) {
    final nested = data['data'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return data;
  }

  List<Map<String, dynamic>> _pickList(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final items = _asList(source[key]);
      if (items.isNotEmpty || source.containsKey(key)) return items;
    }
    if (source['data'] is List) return _asList(source['data']);
    return const [];
  }

  Map<String, dynamic> _pickMap(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = source[key];
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    }
    return const {};
  }

  void _mergeProfileData(
    Map<String, dynamic> profile,
    Map<String, dynamic> preferences,
  ) {
    if (profile.isNotEmpty) {
      _profileForm['name'] =
          _firstString([
            profile['name'],
            profile['nombre'],
            profile['full_name'],
          ]) ??
          _profileForm['name'];
      _profileForm['base'] =
          _firstString([
            profile['base'],
            profile['base_airport'],
            profile['base_code'],
            profile['city'],
          ]) ??
          _profileForm['base'];
      _profileForm['languages'] =
          _firstString([
            profile['languages'],
            profile['idiomas'],
            profile['language_summary'],
          ]) ??
          _profileForm['languages'];
      _profileForm['experience'] =
          _firstString([
            profile['experience'],
            profile['experiencia'],
            profile['service_experience'],
          ]) ??
          _profileForm['experience'];
      _profileForm['coverage'] =
          _firstString([
            profile['coverage'],
            profile['cobertura'],
            profile['operational_coverage'],
          ]) ??
          _profileForm['coverage'];
      _profileForm['profileState'] =
          _firstString([
            profile['profile_state'],
            profile['estado_perfil'],
            profile['validation_status'],
            profile['document_status'],
            profile['review_status'],
            profile['status'],
          ]) ??
          _profileForm['profileState'];
      _storedOperationalStatus =
          _normalizeCrewOperationalStatus(
            _firstString([
                  profile['current_status'],
                  profile['operational_status'],
                  profile['status_operativo'],
                ]) ??
                '',
          ) ??
          _storedOperationalStatus;
    }

    if (preferences.isNotEmpty) {
      if (preferences.containsKey('notify_assignments')) {
        _configForm['notifyAssignments'] =
            preferences['notify_assignments'] == true;
      }
      if (preferences.containsKey('notify_incidents')) {
        _configForm['notifyIncidents'] =
            preferences['notify_incidents'] == true;
      }
      if (preferences.containsKey('notify_schedule_changes')) {
        _configForm['notifyScheduleChanges'] =
            preferences['notify_schedule_changes'] == true;
      }
      _configForm['personalCoverage'] =
          _firstString([
            preferences['personal_coverage'],
            preferences['coverage'],
          ]) ??
          _configForm['personalCoverage'];
      _configForm['escalationMode'] =
          _firstString([
            preferences['escalation_mode'],
            preferences['escalation'],
          ]) ??
          _configForm['escalationMode'];
    }
  }

  String? _normalizeCrewOperationalStatus(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (const [
      'active',
      'activo',
      'available',
      'disponible',
    ].contains(normalized)) {
      return 'Disponible';
    }
    if (const ['en vuelo', 'in flight', 'vuelo'].contains(normalized)) {
      return 'En vuelo';
    }
    if (const [
      'blocked',
      'bloqueado',
      'inactive',
      'inactivo',
      'no disponible',
    ].contains(normalized)) {
      return 'No disponible';
    }
    if (const ['suspended', 'suspendido'].contains(normalized)) {
      return 'Suspendido';
    }
    if (const ['rest', 'descanso'].contains(normalized)) {
      return 'Descanso';
    }
    return value.trim();
  }

  List<CrewAvailabilityRecord> _expandAvailabilityRecords(
    List<Map<String, dynamic>> records,
  ) {
    final expanded = <CrewAvailabilityRecord>[];
    for (final record in records) {
      final start =
          DateTime.tryParse(
            _firstString([
                  record['fecha'],
                  record['from'],
                  record['date'],
                  record['starts_at'],
                  record['start_datetime'],
                ]) ??
                '',
          ) ??
          DateTime.now();
      final end =
          DateTime.tryParse(
            _firstString([
                  record['to'],
                  record['ends_at'],
                  record['end_datetime'],
                  record['fecha'],
                  record['from'],
                  record['date'],
                ]) ??
                '',
          ) ??
          start;
      final last = DateTime(end.year, end.month, end.day);
      var cursor = DateTime(start.year, start.month, start.day);
      while (!cursor.isAfter(last)) {
        expanded.add(
          CrewAvailabilityRecord.fromJson({
            ...record,
            'fecha': cursor.toIso8601String(),
          }),
        );
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    return expanded;
  }
}
