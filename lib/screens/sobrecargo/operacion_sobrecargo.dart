part of 'pantalla_espacio_sobrecargo.dart';

class CrewOperationView extends StatefulWidget {
  const CrewOperationView({
    super.key,
    required this.assignment,
    this.drawerBranchLabel,
    this.drawerTitle,
    this.drawerUserEmail,
    this.drawerItems,
    this.drawerGroups,
    this.onSelectDrawerSection,
    this.onLogout,
    this.initialStepId,
    this.openIncidentOnLoad = false,
    this.drawerUserPhone,
  });

  final CrewAssignment assignment;
  final String? drawerBranchLabel;
  final String? drawerTitle;
  final String? drawerUserEmail;
  final String? drawerUserPhone;
  final List<RoleWorkspaceItem>? drawerItems;
  final List<RoleWorkspaceDrawerGroup>? drawerGroups;
  final ValueChanged<CrewWorkspaceSection>? onSelectDrawerSection;
  final VoidCallback? onLogout;
  final String? initialStepId;
  final bool openIncidentOnLoad;

  @override
  State<CrewOperationView> createState() => _CrewOperationViewState();
}

class _CrewOperationViewState extends State<CrewOperationView> {
  final ApiClient _api = ApiClient.instance;
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _primaryActionKey = GlobalKey();
  final GlobalKey _stepContentKey = GlobalKey();

  Map<String, dynamic> _workflow = const {};
  bool _loading = true;
  bool _saving = false;
  String? _busyActionId;
  String _error = '';
  String _selectedStepId = '';
  String _selectedTrackingId = '';
  final Set<String> _expandedChecklistGroupIds = <String>{};
  final Set<String> _expandedChecklistItemIds = <String>{};
  bool _didAutoOpenIncident = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  AuthProvider get _auth => context.read<AuthProvider>();

  String get _resolvedDrawerName {
    final provided = widget.drawerTitle?.trim() ?? '';
    if (provided.isNotEmpty) return provided;
    final userName =
        _auth.user?.name.trim().isNotEmpty == true
            ? _auth.user!.name.trim()
            : _auth.displayName.trim();
    return userName.isEmpty ? 'Sobrecargo' : userName;
  }

  String get _resolvedDrawerEmail =>
      widget.drawerUserEmail?.trim().isNotEmpty == true
          ? widget.drawerUserEmail!.trim()
          : (_auth.user?.email ?? 'sin correo');

  String? get _resolvedDrawerPhone {
    final provided = widget.drawerUserPhone?.trim() ?? '';
    if (provided.isNotEmpty) return provided;
    final fallback = _auth.user?.phone.trim() ?? '';
    return fallback.isEmpty ? null : fallback;
  }

  List<RoleWorkspaceItem> get _resolvedDrawerItems =>
      widget.drawerItems ??
      const [
        RoleWorkspaceItem(
          label: 'Inicio',
          shortLabel: 'Inicio',
          icon: Icons.dashboard_customize_rounded,
          screen: SizedBox.shrink(),
        ),
        RoleWorkspaceItem(
          label: 'Mi vuelo',
          shortLabel: 'Mi vuelo',
          icon: Icons.assignment_turned_in_rounded,
          screen: SizedBox.shrink(),
        ),
        RoleWorkspaceItem(
          label: 'Mi disponibilidad',
          shortLabel: 'Disponibilidad',
          icon: Icons.event_available_rounded,
          screen: SizedBox.shrink(),
        ),
        RoleWorkspaceItem(
          label: 'Cuenta',
          shortLabel: 'Cuenta',
          icon: Icons.account_circle_rounded,
          screen: SizedBox.shrink(),
        ),
      ];

  List<RoleWorkspaceDrawerGroup> get _resolvedDrawerGroups =>
      widget.drawerGroups ??
      const [
        RoleWorkspaceDrawerGroup(
          workspaceIndex: 2,
          items: [
            RoleWorkspaceDrawerItem(
              label: 'Estado actual',
              section: CrewWorkspaceSection.availabilityStatus,
            ),
            RoleWorkspaceDrawerItem(
              label: 'Calendario',
              section: CrewWorkspaceSection.availabilityCalendar,
            ),
            RoleWorkspaceDrawerItem(
              label: 'Registrar disponibilidad',
              section: CrewWorkspaceSection.availabilityRegister,
            ),
          ],
        ),
        RoleWorkspaceDrawerGroup(
          workspaceIndex: 3,
          items: [
            RoleWorkspaceDrawerItem(
              label: 'Perfil',
              section: CrewWorkspaceSection.accountProfile,
            ),
            RoleWorkspaceDrawerItem(
              label: 'Documentos',
              section: CrewWorkspaceSection.accountDocuments,
            ),
            RoleWorkspaceDrawerItem(
              label: 'Historial',
              section: CrewWorkspaceSection.accountHistory,
            ),
            RoleWorkspaceDrawerItem(
              label: 'Pagos',
              section: CrewWorkspaceSection.accountPayments,
            ),
            RoleWorkspaceDrawerItem(
              label: 'Configuración',
              section: CrewWorkspaceSection.accountSettings,
            ),
          ],
        ),
      ];

  List<Map<String, dynamic>> _list(dynamic value) =>
      value is List
          ? value
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : const [];

  void _setSavingState(bool saving, {String? actionId}) {
    if (!mounted) return;
    setState(() {
      _saving = saving;
      _busyActionId = saving ? actionId : null;
    });
  }

  bool _isBusyAction(String actionId) => _saving && _busyActionId == actionId;

  Future<void> _handleOverflowAction(String action) async {
    switch (action) {
      case 'back':
        if (mounted) Navigator.of(context).maybePop();
        return;
      case 'refresh':
        await _load();
        return;
      case 'report':
        await _showReport(actionId: 'appbar:report');
        return;
    }
  }

  Future<void> _handleDrawerSectionSelection(
    CrewWorkspaceSection section,
  ) async {
    Navigator.of(context).pop();
    switch (section) {
      case CrewWorkspaceSection.home:
      case CrewWorkspaceSection.availabilityStatus:
      case CrewWorkspaceSection.availabilityCalendar:
      case CrewWorkspaceSection.availabilityRegister:
      case CrewWorkspaceSection.accountHome:
      case CrewWorkspaceSection.accountProfile:
      case CrewWorkspaceSection.accountDocuments:
      case CrewWorkspaceSection.accountHistory:
      case CrewWorkspaceSection.accountPayments:
      case CrewWorkspaceSection.accountSettings:
        if (mounted) Navigator.of(context).pop();
        widget.onSelectDrawerSection?.call(section);
        return;
      case CrewWorkspaceSection.missionOverview:
        if (mounted) Navigator.of(context).pop();
        return;
      case CrewWorkspaceSection.missionValidation:
        await _focusStepSection('validation');
        return;
      case CrewWorkspaceSection.missionPreparation:
        await _focusStepSection('preparation');
        return;
      case CrewWorkspaceSection.missionChecklist:
        await _focusStepSection('checklist');
        return;
      case CrewWorkspaceSection.missionTracking:
        await _focusStepSection('tracking');
        return;
      case CrewWorkspaceSection.missionEvidence:
        await _focusStepSection(_bestEvidenceStepId());
        return;
      case CrewWorkspaceSection.missionIncidents:
        await _showIncidentDialog(actionId: 'drawer:incident');
        return;
      case CrewWorkspaceSection.missionClosure:
        await _focusStepSection('closure');
        return;
    }
  }

  String _bestEvidenceStepId() {
    if (_currentStepId == 'preparation' ||
        _currentStepId == 'checklist' ||
        _currentStepId == 'closure') {
      return _currentStepId;
    }
    return 'checklist';
  }

  CrewWorkspaceSection get _activeDrawerSection {
    switch (_currentStepId) {
      case 'validation':
        return CrewWorkspaceSection.missionValidation;
      case 'preparation':
        return CrewWorkspaceSection.missionPreparation;
      case 'checklist':
        return CrewWorkspaceSection.missionChecklist;
      case 'tracking':
        return CrewWorkspaceSection.missionTracking;
      case 'closure':
        return CrewWorkspaceSection.missionClosure;
      default:
        return CrewWorkspaceSection.missionOverview;
    }
  }

  Widget _buttonIcon(
    IconData icon, {
    required bool busy,
    Color? color,
    double size = 18,
  }) {
    if (!busy) return Icon(icon, color: color, size: size);
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }

  String _buttonLabel(String label, {required bool busy, String? busyLabel}) =>
      busy ? (busyLabel ?? 'Cargando...') : label;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
      if (!mounted) return;
      setState(() {
        _workflow = source;
        _syncSelections();
      });
      if (widget.openIncidentOnLoad && !_didAutoOpenIncident) {
        _didAutoOpenIncident = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(_showIncidentDialog(actionId: 'drawer:incident'));
          }
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _syncSelections() {
    final steps = _flow.steps;
    final current = steps.firstWhere(
      (step) => step.status == 'current',
      orElse:
          () =>
              steps.isNotEmpty
                  ? steps.first
                  : const CrewOperationStepState(
                    id: '',
                    label: '',
                    status: 'pending',
                    available: false,
                    complete: false,
                  ),
    );
    final requestedStepId = widget.initialStepId;
    final hasRequestedStep =
        requestedStepId != null &&
        steps.any((step) => step.id == requestedStepId);
    if (_selectedStepId.isEmpty ||
        !steps.any((step) => step.id == _selectedStepId)) {
      _selectedStepId = hasRequestedStep ? requestedStepId : current.id;
    }

    final validGroupIds = <String>{};
    final validItemIds = <String>{};
    for (final checklist in _allChecklists) {
      final checklistType = '${checklist['type'] ?? ''}';
      for (final group in _groupedChecklist(checklist)) {
        validGroupIds.add(_checklistGroupId(checklistType, group.key));
        for (final item in group.value) {
          validItemIds.add(_checklistItemId(checklistType, item));
        }
      }
    }
    _expandedChecklistGroupIds.removeWhere((id) => !validGroupIds.contains(id));
    _expandedChecklistItemIds.removeWhere((id) => !validItemIds.contains(id));

    final currentChecklist = _checklistForStep(_selectedStepId);
    if (currentChecklist != null) {
      final checklistType = '${currentChecklist['type'] ?? ''}';
      final groups = _groupedChecklist(currentChecklist);
      final hasExpandedCurrentGroup = groups.any(
        (group) => _expandedChecklistGroupIds.contains(
          _checklistGroupId(checklistType, group.key),
        ),
      );
      final currentItems = _itemsForChecklist(currentChecklist);
      final hasExpandedCurrentItem = currentItems.any(
        (item) => _expandedChecklistItemIds.contains(
          _checklistItemId(checklistType, item),
        ),
      );

      if (!hasExpandedCurrentGroup && groups.isNotEmpty) {
        final preferredGroup = groups.firstWhere(
          (group) => group.value.any((item) => !_isChecklistHandled(item)),
          orElse: () => groups.first,
        );
        _expandedChecklistGroupIds.add(
          _checklistGroupId(checklistType, preferredGroup.key),
        );
      }

      if (!hasExpandedCurrentItem && currentItems.isNotEmpty) {
        final preferredItem = currentItems.firstWhere(
          (item) => !_isChecklistHandled(item),
          orElse: () => currentItems.first,
        );
        _expandedChecklistItemIds.add(
          _checklistItemId(checklistType, preferredItem),
        );
      }
    }

    final milestones = _flow.trackingMilestones;
    if (_selectedTrackingId.isEmpty ||
        !milestones.any((item) => item.id == _selectedTrackingId)) {
      final preferred = milestones.firstWhere(
        (item) => item.state == 'current',
        orElse:
            () => milestones.firstWhere(
              (item) => item.state == 'pending',
              orElse:
                  () =>
                      milestones.isEmpty
                          ? const CrewOperationTrackingMilestone(
                            id: '',
                            label: '',
                            detail: '',
                            state: 'pending',
                            timestamp: '',
                            action: null,
                          )
                          : milestones.first,
            ),
      );
      _selectedTrackingId = preferred.id;
    }
  }

  Future<void> _confirmAssignment({
    String actionId = 'confirm_assignment',
  }) async {
    if (_saving) return;
    _setSavingState(true, actionId: actionId);
    try {
      await _api.respondCrewAssignment(
        operationId: widget.assignment.id,
        status: 'Confirmado',
      );
      await _load();
      _showMessage('Vuelo confirmado con operaciones.');
    } catch (error) {
      _showMessage('$error');
    } finally {
      _setSavingState(false);
    }
  }

  Future<void> _runAction(
    Map<String, dynamic> action, {
    String? actionId,
  }) async {
    if (_saving) return;
    final busyId =
        actionId ??
        'workflow:${action['type'] ?? action['status'] ?? action['label'] ?? 'action'}';
    try {
      final type = '${action['type'] ?? ''}'.toLowerCase();
      final operationId = widget.assignment.resolvedOperationId;
      if (type == 'submit_report') {
        await _showReport(actionId: busyId);
        return;
      }
      _setSavingState(true, actionId: busyId);
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
          step: '${action['status'] ?? ''}',
        );
      }
      await _load();
    } catch (error) {
      _showMessage('$error');
    } finally {
      _setSavingState(false);
    }
  }

  Future<void> _editItem(
    Map<String, dynamic> checklist,
    Map<String, dynamic> item, {
    String? actionId,
  }) async {
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
                      if ('${item['description'] ?? ''}'.trim().isNotEmpty)
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
                            child: Text('Correcto'),
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
    await _saveChecklistItem(
      checklist: checklist,
      item: item,
      status: result['status'] ?? 'pending',
      notes: result['notes'] ?? '',
      actionId: actionId,
    );
  }

  Future<void> _saveChecklistItem({
    required Map<String, dynamic> checklist,
    required Map<String, dynamic> item,
    required String status,
    String notes = '',
    String? actionId,
  }) async {
    if (_saving) return;
    final previousSummary = _summaryForChecklist(checklist);
    final previousStepId = _stepIdForChecklistType(
      '${checklist['type'] ?? ''}',
    );
    final checklistType = '${checklist['type'] ?? ''}';
    _setSavingState(
      true,
      actionId:
          actionId ?? 'checklist:${checklist['type']}:${item['id']}:$status',
    );
    try {
      await _api.updateCrewChecklistItem(
        operationId: widget.assignment.resolvedOperationId,
        checklistType: '${checklist['type'] ?? ''}',
        itemId: '${item['id'] ?? ''}',
        status: status,
        notes: notes,
      );
      await _load();
      if (mounted) {
        final refreshedChecklist = _mergedChecklistOfType(checklistType);
        final refreshedSummary = _summaryForChecklist(refreshedChecklist);
        final completedChecklist =
            previousSummary.pending > 0 && refreshedSummary.pending == 0;
        if (completedChecklist) {
          setState(() => _selectedStepId = _flow.currentStepId);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToPrimaryActionSection(fromStepId: previousStepId);
          });
        }
      }
      _showMessage('Checklist actualizado.');
    } catch (error) {
      _showMessage('$error');
    } finally {
      _setSavingState(false);
    }
  }

  Future<void> _reportChecklistFailure(
    Map<String, dynamic> checklist,
    Map<String, dynamic> item, {
    String? actionId,
  }) async {
    final crewId = context.read<AuthProvider>().user?.id ?? '';
    final description = TextEditingController(text: '${item['notes'] ?? ''}');
    File? evidence;
    final result = await showModalBottomSheet<bool>(
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
                        'Reportar falla',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('${item['label'] ?? 'Elemento'}'),
                      const SizedBox(height: 16),
                      TextField(
                        controller: description,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'Describe el problema',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await _picker.pickImage(
                                source: ImageSource.camera,
                                imageQuality: 88,
                              );
                              if (picked == null) return;
                              setSheetState(() => evidence = File(picked.path));
                            },
                            icon: const Icon(Icons.camera_alt_rounded),
                            label: const Text('Tomar foto'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await _picker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 88,
                              );
                              if (picked == null) return;
                              setSheetState(() => evidence = File(picked.path));
                            },
                            icon: const Icon(Icons.photo_library_rounded),
                            label: const Text('Galería'),
                          ),
                        ],
                      ),
                      if (evidence != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Evidencia lista: ${evidence!.path.split('/').last}',
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed:
                            description.text.trim().isEmpty
                                ? null
                                : () => Navigator.pop(context, true),
                        child: const Text('Guardar reporte'),
                      ),
                    ],
                  ),
                ),
          ),
    );
    final failureDescription = description.text.trim();
    description.dispose();
    if (result != true || failureDescription.isEmpty) return;

    if (_saving) return;
    _setSavingState(
      true,
      actionId: actionId ?? 'failure:${checklist['type']}:${item['id']}',
    );
    try {
      await _api.createCrewIncident(
        operationId: widget.assignment.resolvedOperationId,
        crewId: crewId,
        description:
            '${item['label'] ?? 'Checklist'}: $failureDescription'.trim(),
        category: 'cabina',
        priority: item['critical'] == true ? 'alta' : 'media',
        phase: _phaseForChecklist(checklist),
        evidence: evidence,
      );
      await _api.updateCrewChecklistItem(
        operationId: widget.assignment.resolvedOperationId,
        checklistType: '${checklist['type'] ?? ''}',
        itemId: '${item['id'] ?? ''}',
        status: 'failed',
        notes: failureDescription,
      );
      await _load();
      _showMessage('Falla registrada para seguimiento.');
    } catch (error) {
      _showMessage('$error');
    } finally {
      _setSavingState(false);
    }
  }

  Future<void> _showIncidentDialog({String actionId = 'incident'}) async {
    final crewId = context.read<AuthProvider>().user?.id ?? '';
    final description = TextEditingController();
    String category = 'cabina';
    String priority = 'media';
    String phase = 'Pre-vuelo';
    File? evidence;

    final result = await showModalBottomSheet<bool>(
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
                        'Reportar incidencia',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'cabina',
                            child: Text('Cabina'),
                          ),
                          DropdownMenuItem(
                            value: 'seguridad',
                            child: Text('Seguridad'),
                          ),
                          DropdownMenuItem(
                            value: 'servicio',
                            child: Text('Servicio'),
                          ),
                          DropdownMenuItem(
                            value: 'operacion',
                            child: Text('Operación'),
                          ),
                          DropdownMenuItem(value: 'otro', child: Text('Otro')),
                        ],
                        onChanged:
                            (value) => setSheetState(
                              () => category = value ?? category,
                            ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: priority,
                        decoration: const InputDecoration(
                          labelText: 'Prioridad',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'baja', child: Text('Baja')),
                          DropdownMenuItem(
                            value: 'media',
                            child: Text('Media'),
                          ),
                          DropdownMenuItem(value: 'alta', child: Text('Alta')),
                          DropdownMenuItem(
                            value: 'critica',
                            child: Text('Crítica'),
                          ),
                        ],
                        onChanged:
                            (value) => setSheetState(
                              () => priority = value ?? priority,
                            ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: phase,
                        decoration: const InputDecoration(labelText: 'Fase'),
                        items: const [
                          DropdownMenuItem(
                            value: 'Pre-vuelo',
                            child: Text('Pre-vuelo'),
                          ),
                          DropdownMenuItem(
                            value: 'Abordaje',
                            child: Text('Abordaje'),
                          ),
                          DropdownMenuItem(
                            value: 'En vuelo',
                            child: Text('En vuelo'),
                          ),
                          DropdownMenuItem(
                            value: 'Post-vuelo',
                            child: Text('Post-vuelo'),
                          ),
                        ],
                        onChanged:
                            (value) =>
                                setSheetState(() => phase = value ?? phase),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: description,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _picker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 88,
                          );
                          if (picked == null) return;
                          setSheetState(() => evidence = File(picked.path));
                        },
                        icon: const Icon(Icons.add_a_photo_rounded),
                        label: Text(
                          evidence == null
                              ? 'Agregar evidencia'
                              : 'Cambiar evidencia',
                        ),
                      ),
                      if (evidence != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            evidence!.path.split('/').last,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed:
                            description.text.trim().isEmpty
                                ? null
                                : () => Navigator.pop(context, true),
                        child: const Text('Enviar incidencia'),
                      ),
                    ],
                  ),
                ),
          ),
    );
    final message = description.text.trim();
    description.dispose();
    if (result != true || message.isEmpty) return;

    if (_saving) return;
    _setSavingState(true, actionId: actionId);
    try {
      await _api.createCrewIncident(
        operationId: widget.assignment.resolvedOperationId,
        crewId: crewId,
        description: message,
        category: category,
        priority: priority,
        phase: phase,
        evidence: evidence,
      );
      _showMessage('Incidencia enviada a operaciones.');
    } catch (error) {
      _showMessage('$error');
    } finally {
      _setSavingState(false);
    }
  }

  Future<void> _pickEvidence(
    Map<String, dynamic> checklist,
    Map<String, dynamic> item,
    ImageSource source, {
    String? actionId,
  }) async {
    if (_saving) return;
    final picked = await _picker.pickImage(source: source, imageQuality: 88);
    if (picked == null || !mounted) return;
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
    _setSavingState(
      true,
      actionId:
          actionId ??
          'evidence:${checklist['type']}:${item['id']}:${source.name}',
    );
    _showMessage('Subiendo fotografía...');
    try {
      await _api.uploadCrewChecklistEvidence(
        operationId: widget.assignment.resolvedOperationId,
        checklistType: '${checklist['type'] ?? ''}',
        itemId: '${item['id'] ?? ''}',
        file: File(picked.path),
      );
      await _load();
      _showMessage('Fotografía registrada correctamente.');
    } catch (error) {
      _showMessage('Error al subir la fotografía. $error');
    } finally {
      _setSavingState(false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _token(dynamic value) {
    return '$value'
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
  }

  bool _isChecklistResolved(Map<String, dynamic> item) {
    final status = _token(item['status']);
    return status == 'completed' || status == 'not applicable';
  }

  bool _isChecklistHandled(Map<String, dynamic> item) {
    final status = _token(item['status']);
    return _isChecklistResolved(item) || status == 'failed';
  }

  String _checklistStatusLabel(Map<String, dynamic> item) {
    final status = _token(item['status']);
    if (status == 'completed') return 'Registrado';
    if (status == 'not applicable') return 'No aplica';
    if (status == 'failed') return 'Falla reportada';
    return 'Pendiente';
  }

  String _friendlyChecklistCategory(String value) {
    switch (_token(value)) {
      case 'personal':
        return 'Documentación personal';
      case 'logistics':
        return 'Traslado y presentación';
      case 'operation':
        return 'Información del vuelo';
      case 'passengers':
        return 'Pasajeros';
      case 'service':
        return 'Servicio';
      case 'cabin':
        return 'Cabina';
      case 'safety':
        return 'Seguridad';
      default:
        return value.trim().isEmpty ? 'General' : _naturalizeText(value);
    }
  }

  String _friendlyActionLabel(Map<String, dynamic> action) {
    final type = _token(action['type']);
    final status = _token(action['status']);
    if (type == 'checkin') return 'Confirmar llegada';
    if (type == 'cabin ready') return 'Cabina lista';
    if (type == 'passengers ready') return 'Pasajeros a bordo';
    if (type == 'submit report') return 'Enviar cierre';
    if (status.contains('preparation')) return 'Iniciar preparación';
    if (status.contains('preflight')) return 'Abrir checklist pre-vuelo';
    if (status.contains('boarding')) return 'Registrar abordaje';
    if (status.contains('in flight')) return 'Registrar despegue';
    if (status.contains('landed')) return 'Registrar aterrizaje';
    if (status.contains('postflight')) return 'Abrir post-vuelo';
    final label = '${action['label'] ?? ''}'.trim();
    return label.isEmpty ? 'Continuar' : _naturalizeText(label);
  }

  IconData _friendlyActionIcon(Map<String, dynamic> action) {
    final type = _token(action['type']);
    final status = _token(action['status']);
    if (type == 'checkin') return Icons.location_on_rounded;
    if (type == 'cabin ready') return Icons.airline_seat_recline_normal_rounded;
    if (type == 'passengers ready') return Icons.groups_rounded;
    if (type == 'submit report') return Icons.send_rounded;
    if (status.contains('landed')) return Icons.flight_land_rounded;
    if (status.contains('flight')) return Icons.flight_takeoff_rounded;
    return Icons.arrow_forward_rounded;
  }

  String _naturalizeText(String value) {
    final cleaned = value.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return 'Actualización';
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

  List<Map<String, dynamic>> _checklistsOfType(String type) {
    final normalizedType = normalizeCrewChecklistType(type);
    return _allChecklists.where((checklist) {
      return normalizeCrewChecklistType(checklist['type']) == normalizedType;
    }).toList();
  }

  Map<String, dynamic>? _mergedChecklistOfType(String type) {
    final matches = _checklistsOfType(type);
    if (matches.isEmpty) return null;
    final first = matches.first;
    final mergedItems = <Map<String, dynamic>>[];
    for (final checklist in matches) {
      mergedItems.addAll(_itemsForChecklist(checklist));
    }
    return {...first, 'type': type, 'items': mergedItems};
  }

  List<Map<String, dynamic>> _itemsForChecklist(
    Map<String, dynamic> checklist,
  ) {
    return _list(checklist['items']);
  }

  _ChecklistSummary _summaryForChecklist(Map<String, dynamic>? checklist) {
    final items =
        checklist == null
            ? const <Map<String, dynamic>>[]
            : _itemsForChecklist(checklist);
    final resolved = items.where(_isChecklistResolved).length;
    final handled = items.where(_isChecklistHandled).length;
    final pending = items.length - handled;
    return _ChecklistSummary(
      total: items.length,
      resolved: resolved,
      handled: handled,
      pending: pending,
      isComplete: items.isNotEmpty && pending == 0,
    );
  }

  List<MapEntry<String, List<Map<String, dynamic>>>> _groupedChecklist(
    Map<String, dynamic>? checklist,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item
        in checklist == null
            ? const <Map<String, dynamic>>[]
            : _itemsForChecklist(checklist)) {
      final key = _friendlyChecklistCategory(
        '${item['category'] ?? item['group'] ?? ''}',
      );
      groups.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(item);
    }
    return groups.entries.toList();
  }

  String _phaseForChecklist(Map<String, dynamic> checklist) {
    switch (_token(checklist['type'])) {
      case 'postflight':
        return 'Post-vuelo';
      case 'preflight':
      case 'preparation':
        return 'Pre-vuelo';
      default:
        return 'Operación';
    }
  }

  List<Map<String, dynamic>> get _allChecklists =>
      _list(_workflow['checklists']);
  Map<String, dynamic> get _finalReport =>
      _workflow['final_report'] is Map
          ? Map<String, dynamic>.from(_workflow['final_report'])
          : const {};

  Map<String, dynamic>? get _preparationChecklist =>
      _mergedChecklistOfType('preparation');
  Map<String, dynamic>? get _preflightChecklist =>
      _mergedChecklistOfType('preflight');
  Map<String, dynamic>? get _postflightChecklist =>
      _mergedChecklistOfType('postflight');

  _ChecklistSummary get _preparationSummary =>
      _summaryForChecklist(_preparationChecklist);
  _ChecklistSummary get _preflightSummary =>
      _summaryForChecklist(_preflightChecklist);
  _ChecklistSummary get _postflightSummary =>
      _summaryForChecklist(_postflightChecklist);

  CrewOperationFlowSnapshot get _flow => CrewOperationFlowSnapshot.fromPayload(
    workflow: _workflow,
    canRespondToAssignment: widget.assignment.canRespondToAssignment,
  );

  String get _currentStepId {
    if (_flow.steps.any((step) => step.id == _selectedStepId)) {
      return _selectedStepId;
    }
    return _flow.currentStepId;
  }

  Map<String, dynamic>? _checklistForStep(String stepId) {
    switch (stepId) {
      case 'preparation':
        return _preparationChecklist;
      case 'checklist':
        return _preflightChecklist;
      case 'closure':
        return _postflightChecklist;
      default:
        return null;
    }
  }

  String _checklistGroupId(String checklistType, String label) =>
      '${_token(checklistType)}::group::${_token(label)}';

  String _stepIdForChecklistType(String checklistType) {
    switch (_token(checklistType)) {
      case 'preparation':
        return 'preparation';
      case 'preflight':
        return 'checklist';
      case 'postflight':
        return 'closure';
      default:
        return '';
    }
  }

  String _checklistItemId(String checklistType, Map<String, dynamic> item) =>
      '${_token(checklistType)}::item::${item['id'] ?? item['code'] ?? item['label'] ?? ''}';

  bool _isChecklistGroupExpanded(String checklistType, String label) =>
      _expandedChecklistGroupIds.contains(
        _checklistGroupId(checklistType, label),
      );

  bool _isChecklistItemExpanded(
    String checklistType,
    Map<String, dynamic> item,
  ) =>
      _expandedChecklistItemIds.contains(_checklistItemId(checklistType, item));

  void _toggleChecklistGroup(String checklistType, String label) {
    final id = _checklistGroupId(checklistType, label);
    setState(() {
      if (_expandedChecklistGroupIds.contains(id)) {
        _expandedChecklistGroupIds.remove(id);
      } else {
        _expandedChecklistGroupIds.add(id);
      }
    });
  }

  void _toggleChecklistItem(String checklistType, Map<String, dynamic> item) {
    final id = _checklistItemId(checklistType, item);
    setState(() {
      if (_expandedChecklistItemIds.contains(id)) {
        _expandedChecklistItemIds.remove(id);
      } else {
        _expandedChecklistItemIds.add(id);
      }
    });
  }

  Future<void> _scrollToPrimaryActionSection({String fromStepId = ''}) async {
    if (!mounted) return;
    final targetContext = _primaryActionKey.currentContext;
    if (targetContext != null) {
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
      return;
    }

    if (!_scrollController.hasClients) return;
    final fallbackOffset =
        _scrollController.offset > 320 ? _scrollController.offset - 320 : 0.0;
    await _scrollController.animateTo(
      fallbackOffset,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _focusStepSection(String stepId) async {
    if (!mounted) return;
    if (_selectedStepId != stepId) {
      setState(() => _selectedStepId = stepId);
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final targetContext = _stepContentKey.currentContext;
      if (targetContext != null) {
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          alignment: 0.08,
        );
      }
    });
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

  Future<void> _showReport({String actionId = 'submit_report'}) async {
    final existing = _finalReport;
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
    if (report == null) return;
    if (_saving) return;
    try {
      _setSavingState(true, actionId: actionId);
      await _api.submitCrewFinalReport(
        operationId: widget.assignment.resolvedOperationId,
        report: report,
      );
      await _load();
      _showMessage('Operación enviada correctamente.');
    } catch (error) {
      _showMessage('$error');
    } finally {
      _setSavingState(false);
    }
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
              'Mi vuelo',
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
              'Reporte',
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

  Widget _stepper() {
    final steps = _flow.steps;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            steps.map((step) {
              final selected = step.id == _currentStepId;
              final color = switch (step.status) {
                'completed' => const Color(0xFF16845B),
                'current' => const Color(0xFFB7791F),
                'blocked' => const Color(0xFFBFC7D1),
                _ => const Color(0xFF385A72),
              };
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selected,
                  label: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(step.label),
                      Text(
                        step.status == 'completed'
                            ? 'Completado'
                            : step.status == 'current'
                            ? 'Activo'
                            : step.status == 'blocked'
                            ? 'Bloqueado'
                            : 'Pendiente',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  onSelected:
                      step.available
                          ? (_) => setState(() => _selectedStepId = step.id)
                          : null,
                  selectedColor: color.withValues(alpha: 0.16),
                  side: BorderSide(color: color),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _primaryActionBanner() {
    final action = _flow.primaryAction;
    final primaryActionId = 'primary:${action.kind}:${action.cta}';
    final primaryBusy = _isBusyAction(primaryActionId);
    final incidentBusy = _isBusyAction('primary:incident');
    Future<void> Function()? onPressed;
    switch (action.kind) {
      case 'confirm_assignment':
        onPressed = () => _confirmAssignment(actionId: primaryActionId);
        break;
      case 'workflow_action':
        if (action.action != null) {
          onPressed =
              () => _runAction(action.action!, actionId: primaryActionId);
        }
        break;
      case 'submit_report':
        onPressed = () => _showReport(actionId: primaryActionId);
        break;
      case 'open_checklist':
        onPressed = () => _focusStepSection('checklist');
        break;
      case 'open_tracking':
        onPressed = () => _focusStepSection('tracking');
        break;
      case 'open_closure':
        onPressed = () => _focusStepSection('closure');
        break;
    }
    return Card(
      key: _primaryActionKey,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Acción principal',
              style: TextStyle(
                color: Color(0xFFB7791F),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              action.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(action.detail),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (action.cta.isNotEmpty)
                  FilledButton.icon(
                    onPressed: _saving ? null : onPressed,
                    icon: _buttonIcon(
                      Icons.arrow_forward_rounded,
                      busy: primaryBusy,
                    ),
                    label: Text(
                      _buttonLabel(
                        action.cta,
                        busy: primaryBusy,
                        busyLabel: 'Procesando...',
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed:
                      _saving
                          ? null
                          : () =>
                              _showIncidentDialog(actionId: 'primary:incident'),
                  icon: _buttonIcon(
                    Icons.warning_amber_rounded,
                    busy: incidentBusy,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  label: Text(
                    _buttonLabel('Reportar incidencia', busy: incidentBusy),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _validationStep() {
    final confirmBusy = _isBusyAction('validation:confirm');
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paso 1 · Validar vuelo',
              style: TextStyle(
                color: Color(0xFFB7791F),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Confirma que recibiste y puedes realizar esta asignación.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _factPill('Ruta', widget.assignment.route),
                _factPill('Fecha', _compactCrewDate(widget.assignment.date)),
                _factPill('Reporte', widget.assignment.showTime),
                _factPill('Aeronave', widget.assignment.aircraft),
                _factPill('Pasajeros', '${widget.assignment.passengers} pax'),
              ],
            ),
            const SizedBox(height: 16),
            if (!_flow.assignmentConfirmed)
              FilledButton.icon(
                onPressed:
                    _saving
                        ? null
                        : () =>
                            _confirmAssignment(actionId: 'validation:confirm'),
                icon: _buttonIcon(
                  Icons.check_circle_outline_rounded,
                  busy: confirmBusy,
                ),
                label: Text(
                  _buttonLabel(
                    'Confirmar vuelo',
                    busy: confirmBusy,
                    busyLabel: 'Confirmando...',
                  ),
                ),
              )
            else
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16845B),
                ),
                title: Text('Vuelo confirmado'),
                subtitle: Text('La asignación ya está validada.'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _factPill(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E7ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _checklistStep({
    required String eyebrow,
    required String title,
    required Map<String, dynamic>? checklist,
    required _ChecklistSummary summary,
    String? footer,
    Widget? footerAction,
  }) {
    if (checklist == null) {
      return const _InfoTile(
        icon: Icons.lock_clock_rounded,
        title: 'Aún no hay checklist disponible',
        subtitle: 'Esta fase se habilitará conforme avance la operación.',
      );
    }

    final progress =
        summary.total == 0 ? 0.0 : summary.resolved / summary.total;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                color: Color(0xFFB7791F),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${(progress * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 8),
            Text('${summary.resolved} de ${summary.total} completados'),
            if (summary.total == 0) ...[
              const SizedBox(height: 16),
              const _InfoTile(
                icon: Icons.playlist_remove_rounded,
                title: 'Checklist sin elementos configurados.',
                subtitle:
                    'Esta fase sigue pendiente hasta que backend entregue elementos reales.',
              ),
            ],
            const SizedBox(height: 16),
            ..._groupedChecklist(checklist).map(
              (group) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _checklistGroupCard(checklist, group.key, group.value),
              ),
            ),
            if (footer != null || footerAction != null) ...[
              const SizedBox(height: 14),
              if (footer != null)
                Text(
                  footer,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              if (footerAction != null) ...[
                const SizedBox(height: 10),
                footerAction,
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _checklistGroupCard(
    Map<String, dynamic> checklist,
    String label,
    List<Map<String, dynamic>> items,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final checklistType = '${checklist['type'] ?? ''}';
    final isExpanded = _isChecklistGroupExpanded(checklistType, label);
    final handled = items.where(_isChecklistHandled).length;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isExpanded
                  ? scheme.primary.withValues(alpha: 0.22)
                  : scheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _toggleChecklistGroup(checklistType, label),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$handled/${items.length} registrados',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children:
                    items
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _checklistItemCard(checklist, item),
                          ),
                        )
                        .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _checklistItemCard(
    Map<String, dynamic> checklist,
    Map<String, dynamic> item,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final checklistType = '${checklist['type'] ?? ''}';
    final isExpanded = _isChecklistItemExpanded(checklistType, item);
    final status = _token(item['status']);
    final title = '${item['label'] ?? item['code'] ?? 'Elemento'}';
    final icon =
        _isChecklistResolved(item)
            ? Icons.check_circle_rounded
            : status == 'failed'
            ? Icons.error_rounded
            : Icons.radio_button_unchecked_rounded;
    final iconColor =
        _isChecklistResolved(item)
            ? Colors.green.shade700
            : status == 'failed'
            ? scheme.error
            : scheme.onSurfaceVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              isExpanded
                  ? scheme.primary.withValues(alpha: 0.34)
                  : scheme.outlineVariant,
          width: isExpanded ? 1.4 : 1,
        ),
        boxShadow:
            isExpanded
                ? [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
                : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _toggleChecklistItem(checklistType, item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: iconColor, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _checklistStatusLabel(item),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Divider(
                      height: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.8),
                    ),
                  ),
                  _checklistDetailCard(checklist, item),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _checklistDetailCard(
    Map<String, dynamic> checklist,
    Map<String, dynamic> item,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final checklistType = '${checklist['type'] ?? ''}';
    final itemId = '${item['id'] ?? ''}';
    final evidence = _list(item['evidence_files']);
    final failed = _token(item['status']) == 'failed';
    final completeActionId = 'checklist:$checklistType:$itemId:completed';
    final noApplyActionId = 'checklist:$checklistType:$itemId:not_applicable';
    final failureActionId = 'failure:$checklistType:$itemId';
    final noteActionId = 'note:$checklistType:$itemId';
    final cameraActionId = 'evidence:$checklistType:$itemId:camera';
    final galleryActionId = 'evidence:$checklistType:$itemId:gallery';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ('${item['description'] ?? ''}'.trim().isNotEmpty) ...[
          Text(
            '${item['description']}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          '¿Todo está correcto?',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if ('${item['notes'] ?? ''}'.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Nota',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${item['notes']}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed:
                    _saving
                        ? null
                        : () => _saveChecklistItem(
                          checklist: checklist,
                          item: item,
                          status: 'completed',
                          actionId: completeActionId,
                        ),
                icon: _buttonIcon(
                  Icons.check_rounded,
                  busy: _isBusyAction(completeActionId),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                label: Text(
                  _buttonLabel(
                    'Correcto',
                    busy: _isBusyAction(completeActionId),
                    busyLabel: 'Guardando...',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _saving
                        ? null
                        : () => _saveChecklistItem(
                          checklist: checklist,
                          item: item,
                          status: 'not_applicable',
                          actionId: noApplyActionId,
                        ),
                icon: _buttonIcon(
                  Icons.remove_rounded,
                  busy: _isBusyAction(noApplyActionId),
                  color: scheme.primary,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                label: Text(
                  _buttonLabel(
                    'No aplica',
                    busy: _isBusyAction(noApplyActionId),
                    busyLabel: 'Guardando...',
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _saving
                        ? null
                        : () => _reportChecklistFailure(
                          checklist,
                          item,
                          actionId: failureActionId,
                        ),
                icon: _buttonIcon(
                  Icons.warning_amber_rounded,
                  busy: _isBusyAction(failureActionId),
                  color: scheme.error,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: scheme.errorContainer.withValues(
                    alpha: 0.28,
                  ),
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error.withValues(alpha: 0.25)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                label: Text(
                  _buttonLabel(
                    'Reportar falla',
                    busy: _isBusyAction(failureActionId),
                    busyLabel: 'Guardando...',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _saving
                        ? null
                        : () =>
                            _editItem(checklist, item, actionId: noteActionId),
                icon: _buttonIcon(
                  failed ? Icons.edit_note_rounded : Icons.note_add_outlined,
                  busy: _isBusyAction(noteActionId),
                  color: const Color(0xFF9A6700),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: const Color(0xFFFFF4D6),
                  foregroundColor: const Color(0xFF9A6700),
                  side: const BorderSide(color: Color(0xFFE9CF7A)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                label: Text(
                  _buttonLabel(
                    failed ? 'Editar nota' : 'Agregar nota',
                    busy: _isBusyAction(noteActionId),
                    busyLabel: 'Guardando...',
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Evidencia',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _saving
                        ? null
                        : () => _pickEvidence(
                          checklist,
                          item,
                          ImageSource.camera,
                          actionId: cameraActionId,
                        ),
                icon: _buttonIcon(
                  Icons.camera_alt_rounded,
                  busy: _isBusyAction(cameraActionId),
                  color: scheme.primary,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                label: Text(
                  _buttonLabel(
                    'Tomar foto',
                    busy: _isBusyAction(cameraActionId),
                    busyLabel: 'Subiendo...',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _saving
                        ? null
                        : () => _pickEvidence(
                          checklist,
                          item,
                          ImageSource.gallery,
                          actionId: galleryActionId,
                        ),
                icon: _buttonIcon(
                  Icons.photo_library_rounded,
                  busy: _isBusyAction(galleryActionId),
                  color: scheme.primary,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                label: Text(
                  _buttonLabel(
                    'Galería',
                    busy: _isBusyAction(galleryActionId),
                    busyLabel: 'Subiendo...',
                  ),
                ),
              ),
            ),
          ],
        ),
        if (evidence.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Evidencias adjuntas',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children:
                evidence.asMap().entries.map((entry) {
                  final index = entry.key;
                  final file = entry.value;
                  final url = _evidenceUrl(file);
                  final name =
                      '${file['original_name'] ?? file['name'] ?? file['file_path'] ?? 'evidencia_${index + 1}'}';
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == evidence.length - 1 ? 0 : 8,
                    ),
                    child: InkWell(
                      onTap:
                          url.isEmpty
                              ? null
                              : () => _showSavedEvidence(url, file, name),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 52,
                                height: 52,
                                color: scheme.surfaceContainerHigh,
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name.split('/').last,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _trackingStep() {
    final milestones = _flow.trackingMilestones;
    final selected = milestones.firstWhere(
      (item) => item.id == _selectedTrackingId,
      orElse:
          () =>
              milestones.isEmpty
                  ? const CrewOperationTrackingMilestone(
                    id: '',
                    label: '',
                    detail: '',
                    state: 'pending',
                    timestamp: '',
                    action: null,
                  )
                  : milestones.first,
    );
    final completed =
        milestones.where((item) => item.state == 'completed').length;
    final progress = milestones.isEmpty ? 0.0 : completed / milestones.length;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paso 4 · Seguimiento',
              style: TextStyle(
                color: Color(0xFFB7791F),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Progreso de la operación',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${(progress * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 8),
            Text('$completed de ${milestones.length} eventos registrados'),
            const SizedBox(height: 16),
            ...milestones.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _selectedTrackingId = item.id),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          item.id == selected.id
                              ? const Color(0xFFEEF5FB)
                              : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            item.id == selected.id
                                ? const Color(0xFF385A72)
                                : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          item.state == 'completed'
                              ? '✓'
                              : item.state == 'current'
                              ? '●'
                              : '○',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.timestamp.isNotEmpty
                                    ? item.timestamp
                                    : item.state == 'current'
                                    ? 'Siguiente acción'
                                    : 'Pendiente',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (selected.id.isNotEmpty) ...[
              const Divider(height: 28),
              Text(
                selected.label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(selected.detail),
              const SizedBox(height: 10),
              if (selected.timestamp.isNotEmpty)
                Text('Registrado: ${selected.timestamp}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (selected.action != null)
                    Builder(
                      builder: (context) {
                        final actionId = 'tracking:${selected.id}';
                        final busy = _isBusyAction(actionId);
                        return FilledButton.icon(
                          onPressed:
                              _saving
                                  ? null
                                  : () => _runAction(
                                    selected.action!,
                                    actionId: actionId,
                                  ),
                          icon: _buttonIcon(
                            _friendlyActionIcon(selected.action!),
                            busy: busy,
                          ),
                          label: Text(
                            _buttonLabel(
                              _friendlyActionLabel(selected.action!),
                              busy: busy,
                              busyLabel: 'Procesando...',
                            ),
                          ),
                        );
                      },
                    ),
                  OutlinedButton.icon(
                    onPressed:
                        _saving
                            ? null
                            : () => _showIncidentDialog(
                              actionId: 'tracking:incident',
                            ),
                    icon: _buttonIcon(
                      Icons.warning_amber_rounded,
                      busy: _isBusyAction('tracking:incident'),
                      color: Theme.of(context).colorScheme.error,
                    ),
                    label: Text(
                      _buttonLabel(
                        'Reportar incidencia',
                        busy: _isBusyAction('tracking:incident'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _closureStep() {
    final readyToClose =
        _postflightChecklist != null &&
        _postflightSummary.isComplete &&
        _finalReport.isEmpty;
    return _checklistStep(
      eyebrow: 'Paso 5 · Checklist post-vuelo',
      title: 'Cierre operativo',
      checklist: _postflightChecklist,
      summary: _postflightSummary,
      footer:
          readyToClose
              ? 'Checklist completo. Ya puedes enviar el cierre final.'
              : _finalReport.isNotEmpty
              ? 'El reporte final ya fue enviado.'
              : 'Completa el checklist post-vuelo para habilitar el cierre.',
      footerAction:
          readyToClose
              ? FilledButton.icon(
                onPressed:
                    _saving
                        ? null
                        : () => _showReport(actionId: 'closure:submit'),
                icon: _buttonIcon(
                  Icons.send_rounded,
                  busy: _isBusyAction('closure:submit'),
                ),
                label: Text(
                  _buttonLabel(
                    'Finalizar operación',
                    busy: _isBusyAction('closure:submit'),
                    busyLabel: 'Enviando...',
                  ),
                ),
              )
              : _finalReport.isNotEmpty
              ? OutlinedButton.icon(
                onPressed: _showReport,
                icon: const Icon(Icons.description_rounded),
                label: const Text('Consultar reporte final'),
              )
              : null,
    );
  }

  Widget _operationSummaryCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final workflowStatus = _token(_flow.workflowStatus);
    final showClosureState =
        workflowStatus == 'report pending' || _finalReport.isNotEmpty;

    final items =
        _flow.steps
            .map(
              (step) => _OperationChecklistState(
                label: step.label,
                status: step.status,
              ),
            )
            .toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen de operación',
              style: TextStyle(
                color: Color(0xFFB7791F),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        item.icon,
                        color: item.color(scheme),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.statusLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: item.color(scheme),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showClosureState) ...[
              const SizedBox(height: 4),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      _finalReport.isNotEmpty
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color:
                          _finalReport.isNotEmpty
                              ? const Color(0xFF16845B)
                              : scheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cierre de operación',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _finalReport.isNotEmpty ? 'Completado' : 'Pendiente',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                _finalReport.isNotEmpty
                                    ? const Color(0xFF16845B)
                                    : scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepContent() {
    switch (_currentStepId) {
      case 'validation':
        return _validationStep();
      case 'preparation':
        return _checklistStep(
          eyebrow: 'Paso 2 · Preparación',
          title: 'Preparación de cabina',
          checklist: _preparationChecklist,
          summary: _preparationSummary,
          footer:
              _preparationSummary.total == 0
                  ? 'Checklist sin elementos configurados.'
                  : !_preparationSummary.isComplete
                  ? 'Faltan ${_preparationSummary.pending} elementos por resolver.'
                  : 'Preparación completa. Ya puedes continuar con el checklist pre-vuelo.',
        );
      case 'checklist':
        return _checklistStep(
          eyebrow: 'Paso 3 · Checklist pre-vuelo',
          title: 'Validación previa al abordaje',
          checklist: _preflightChecklist,
          summary: _preflightSummary,
          footer:
              _preflightSummary.total == 0
                  ? 'Checklist sin elementos configurados.'
                  : !_preflightSummary.isComplete
                  ? 'Faltan ${_preflightSummary.pending} elementos por resolver.'
                  : 'Checklist pre-vuelo completo. El seguimiento queda habilitado.',
        );
      case 'tracking':
        return _trackingStep();
      case 'closure':
        return _closureStep();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: const Color(0xFF0C1B2A),
        child: SafeArea(
          child: RoleWorkspaceDrawerContent(
            branchLabel: _resolvedDrawerName,
            roleLabel: 'Sobrecargo',
            title: _resolvedDrawerName,
            userEmail: _resolvedDrawerEmail,
            userPhone: _resolvedDrawerPhone,
            items: _resolvedDrawerItems,
            groups: _resolvedDrawerGroups,
            selectedIndex: 1,
            activeSection: _activeDrawerSection,
            onSelect: (index) {
              Navigator.of(context).pop();
              if (index == 1) {
                Navigator.of(context).pop();
                return;
              }
              if (mounted) Navigator.of(context).pop();
              final section = switch (index) {
                0 => CrewWorkspaceSection.home,
                2 => CrewWorkspaceSection.availabilityStatus,
                3 => CrewWorkspaceSection.accountHome,
                _ => CrewWorkspaceSection.home,
              };
              widget.onSelectDrawerSection?.call(section);
            },
            onSelectSection: (workspaceIndex, {Object? section}) {
              if (section is! CrewWorkspaceSection) return;
              unawaited(_handleDrawerSectionSelection(section));
            },
            onLogout: widget.onLogout ?? _auth.signOut,
          ),
        ),
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Abrir menú',
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Abrir opciones',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) => _handleOverflowAction(value),
            itemBuilder:
                (context) => [
                  const PopupMenuItem<String>(
                    value: 'back',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.arrow_back_rounded),
                      title: Text('Volver a Mi vuelo'),
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'refresh',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.refresh_rounded),
                      title: Text('Refrescar'),
                    ),
                  ),
                  if (_finalReport.isNotEmpty)
                    const PopupMenuItem<String>(
                      value: 'report',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.description_rounded),
                        title: Text('Consultar reporte'),
                      ),
                    ),
                ],
          ),
        ],
        title: const Text('Mi vuelo'),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                if (_loading) const LinearProgressIndicator(),
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                if (_loading && _workflow.isEmpty)
                  const _InfoTile(
                    icon: Icons.sync_rounded,
                    title: 'Cargando checklist...',
                    subtitle:
                        'Estamos consultando el workflow operativo más reciente.',
                  ),
                if (_error.isNotEmpty && _workflow.isEmpty)
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _InfoTile(
                            icon: Icons.cloud_off,
                            title: 'No fue posible cargar el checklist.',
                            subtitle:
                                'Revisa tu conexión y vuelve a intentar para recuperar el workflow.',
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_workflow.isNotEmpty) ...[
                  _flightSummaryCard(),
                  const SizedBox(height: 16),
                  _stepper(),
                  const SizedBox(height: 16),
                  KeyedSubtree(key: _stepContentKey, child: _stepContent()),
                  const SizedBox(height: 16),
                  _primaryActionBanner(),
                  const SizedBox(height: 16),
                  _operationSummaryCard(),
                  if (_finalReport.isNotEmpty) ...[
                    const SizedBox(height: 16),
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
          if (_saving)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.04),
                  ),
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Guardando cambios...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChecklistSummary {
  const _ChecklistSummary({
    required this.total,
    required this.resolved,
    required this.handled,
    required this.pending,
    required this.isComplete,
  });

  final int total;
  final int resolved;
  final int handled;
  final int pending;
  final bool isComplete;
}

class _OperationChecklistState {
  const _OperationChecklistState({required this.label, required this.status});

  final String label;
  final String status;

  String get statusLabel {
    switch (status) {
      case 'completed':
        return 'Completado';
      case 'current':
        return 'Actual';
      case 'blocked':
        return 'Bloqueado';
      case 'available':
        return 'Disponible';
      default:
        return 'Pendiente';
    }
  }

  IconData get icon {
    switch (status) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'current':
        return Icons.trip_origin_rounded;
      case 'blocked':
        return Icons.radio_button_unchecked_rounded;
      case 'available':
        return Icons.radio_button_unchecked_rounded;
      default:
        return Icons.radio_button_unchecked_rounded;
    }
  }

  Color color(ColorScheme scheme) {
    switch (status) {
      case 'completed':
        return const Color(0xFF16845B);
      case 'current':
        return const Color(0xFFB7791F);
      case 'blocked':
        return scheme.onSurfaceVariant;
      case 'available':
        return scheme.primary;
      default:
        return scheme.onSurfaceVariant;
    }
  }
}
