class CrewOperationFlowSnapshot {
  const CrewOperationFlowSnapshot({
    required this.assignmentConfirmed,
    required this.workflowStatus,
    required this.steps,
    required this.currentStepId,
    required this.preparationSummary,
    required this.preflightSummary,
    required this.postflightSummary,
    required this.trackingMilestones,
    required this.primaryAction,
    required this.finalReportAvailable,
  });

  final bool assignmentConfirmed;
  final String workflowStatus;
  final List<CrewOperationStepState> steps;
  final String currentStepId;
  final CrewOperationChecklistSummary preparationSummary;
  final CrewOperationChecklistSummary preflightSummary;
  final CrewOperationChecklistSummary postflightSummary;
  final List<CrewOperationTrackingMilestone> trackingMilestones;
  final CrewOperationPrimaryAction primaryAction;
  final bool finalReportAvailable;

  CrewOperationStepState? stepById(String id) {
    for (final step in steps) {
      if (step.id == id) return step;
    }
    return null;
  }

  bool get trackingComplete =>
      trackingMilestones.isNotEmpty &&
      trackingMilestones.every((item) => item.state == 'completed');

  static CrewOperationFlowSnapshot fromPayload({
    required Map<String, dynamic> workflow,
    required bool canRespondToAssignment,
  }) {
    final assignmentStatus = _token(workflow['assignment_status']);
    final workflowStatus = _token(workflow['status']);
    final allowedActions = _mapList(workflow['allowed_actions']);
    final checklists = _mapList(workflow['checklists']);
    final trackingEvents = _mapList(workflow['tracking_events']);
    final finalReportAvailable = workflow['final_report'] is Map;

    Map<String, dynamic>? checklistByType(String type) {
      final normalizedType = normalizeCrewChecklistType(type);
      for (final checklist in checklists) {
        if (normalizeCrewChecklistType(checklist['type']) == normalizedType) {
          return checklist;
        }
      }
      return null;
    }

    final preparationSummary = CrewOperationChecklistSummary.fromChecklist(
      checklistByType('preparation'),
    );
    final preflightSummary = CrewOperationChecklistSummary.fromChecklist(
      checklistByType('preflight'),
    );
    final postflightSummary = CrewOperationChecklistSummary.fromChecklist(
      checklistByType('postflight'),
    );

    final assignmentConfirmed =
        assignmentStatus == 'confirmed' || !canRespondToAssignment;

    final trackingMilestones = _buildTrackingMilestones(
      trackingEvents,
      allowedActions,
    );

    final steps = _buildSteps(
      assignmentConfirmed: assignmentConfirmed,
      preparationSummary: preparationSummary,
      preflightSummary: preflightSummary,
      postflightSummary: postflightSummary,
      trackingMilestones: trackingMilestones,
    );

    final currentStepId =
        steps
            .firstWhere(
              (step) => step.status == 'current',
              orElse:
                  () => steps.lastWhere(
                    (step) => step.complete,
                    orElse: () => steps.first,
                  ),
            )
            .id;

    final primaryAction = _buildPrimaryAction(
      currentStepId: currentStepId,
      assignmentConfirmed: assignmentConfirmed,
      preparationSummary: preparationSummary,
      preflightSummary: preflightSummary,
      postflightSummary: postflightSummary,
      trackingMilestones: trackingMilestones,
      allowedActions: allowedActions,
      workflowStatus: workflowStatus,
      finalReportAvailable: finalReportAvailable,
    );

    return CrewOperationFlowSnapshot(
      assignmentConfirmed: assignmentConfirmed,
      workflowStatus: workflowStatus,
      steps: steps,
      currentStepId: currentStepId,
      preparationSummary: preparationSummary,
      preflightSummary: preflightSummary,
      postflightSummary: postflightSummary,
      trackingMilestones: trackingMilestones,
      primaryAction: primaryAction,
      finalReportAvailable: finalReportAvailable,
    );
  }
}

class CrewOperationStepState {
  const CrewOperationStepState({
    required this.id,
    required this.label,
    required this.status,
    required this.available,
    required this.complete,
  });

  final String id;
  final String label;
  final String status;
  final bool available;
  final bool complete;
}

class CrewOperationChecklistSummary {
  const CrewOperationChecklistSummary({
    required this.total,
    required this.resolved,
    required this.handled,
    required this.pending,
    required this.failed,
    required this.requiredTotal,
    required this.requiredResolved,
    required this.isLoaded,
    required this.isComplete,
  });

  final int total;
  final int resolved;
  final int handled;
  final int pending;
  final int failed;
  final int requiredTotal;
  final int requiredResolved;
  final bool isLoaded;
  final bool isComplete;

  static CrewOperationChecklistSummary fromChecklist(
    Map<String, dynamic>? checklist,
  ) {
    final items = _mapList(checklist?['items']);
    final requiredItems =
        items.where((item) => item['is_required'] != false).toList();
    final resolved = items.where(_isResolvedStatus).length;
    final handled = items.where(_isHandledStatus).length;
    final pending = items.length - handled;
    final failed =
        items.where((item) => _token(item['status']) == 'failed').length;
    final requiredResolved = requiredItems.where(_isResolvedStatus).length;

    return CrewOperationChecklistSummary(
      total: items.length,
      resolved: resolved,
      handled: handled,
      pending: pending,
      failed: failed,
      requiredTotal: requiredItems.length,
      requiredResolved: requiredResolved,
      isLoaded: items.isNotEmpty,
      isComplete: items.isNotEmpty && pending == 0,
    );
  }
}

class CrewOperationTrackingMilestone {
  const CrewOperationTrackingMilestone({
    required this.id,
    required this.label,
    required this.detail,
    required this.state,
    required this.timestamp,
    required this.action,
  });

  final String id;
  final String label;
  final String detail;
  final String state;
  final String timestamp;
  final Map<String, dynamic>? action;
}

class CrewOperationPrimaryAction {
  const CrewOperationPrimaryAction({
    required this.title,
    required this.detail,
    required this.cta,
    required this.kind,
    this.action,
  });

  final String title;
  final String detail;
  final String cta;
  final String kind;
  final Map<String, dynamic>? action;
}

const List<_TrackingDefinition> _trackingDefinitions = [
  _TrackingDefinition(
    id: 'airport-arrival',
    label: 'Llegué al aeropuerto',
    detail: 'Confirma tu llegada a aeropuerto o base para abrir el flujo.',
    statuses: ['crew_checkin', 'checked_in'],
    titleIncludes: ['llegue al aeropuerto', 'check in operativo', 'check-in'],
    actionMatcher: _checkinMatcher,
  ),
  _TrackingDefinition(
    id: 'aircraft-ready',
    label: 'Cabina preparada',
    detail: 'Registra la revisión de cabina, catering e insumos.',
    statuses: ['cabina_lista', 'cabin_ready'],
    titleIncludes: ['cabina lista', 'aeronave lista'],
    actionMatcher: _cabinReadyMatcher,
  ),
  _TrackingDefinition(
    id: 'passengers-boarded',
    label: 'Pasajeros a bordo',
    detail: 'Confirma la recepción de pasajeros y el abordaje.',
    statuses: ['boarding', 'boarding_completed', 'pasajeros_recibidos'],
    titleIncludes: ['pasajeros', 'abordaje'],
    actionMatcher: _boardingMatcher,
  ),
  _TrackingDefinition(
    id: 'takeoff',
    label: 'Despegue',
    detail: 'Registra el despegue al entrar en vuelo.',
    statuses: ['in_flight'],
    titleIncludes: ['despegue', 'servicio iniciado'],
    actionMatcher: _takeoffMatcher,
  ),
  _TrackingDefinition(
    id: 'landing',
    label: 'Aterrizaje',
    detail: 'Confirma el aterrizaje para habilitar el post-vuelo.',
    statuses: ['landed'],
    titleIncludes: ['aterriz'],
    actionMatcher: _landingMatcher,
  ),
  _TrackingDefinition(
    id: 'passengers-disembarked',
    label: 'Desembarque',
    detail: 'Cierra el traslado de pasajeros y abre el post-vuelo.',
    statuses: ['postflight_pending', 'report_pending', 'crew_completed'],
    titleIncludes: ['desembar', 'postvuelo'],
    actionMatcher: _postflightMatcher,
  ),
];

class _TrackingDefinition {
  const _TrackingDefinition({
    required this.id,
    required this.label,
    required this.detail,
    required this.statuses,
    required this.titleIncludes,
    required this.actionMatcher,
  });

  final String id;
  final String label;
  final String detail;
  final List<String> statuses;
  final List<String> titleIncludes;
  final bool Function(Map<String, dynamic>) actionMatcher;
}

List<CrewOperationStepState> _buildSteps({
  required bool assignmentConfirmed,
  required CrewOperationChecklistSummary preparationSummary,
  required CrewOperationChecklistSummary preflightSummary,
  required CrewOperationChecklistSummary postflightSummary,
  required List<CrewOperationTrackingMilestone> trackingMilestones,
}) {
  final trackingComplete =
      trackingMilestones.isNotEmpty &&
      trackingMilestones.every((item) => item.state == 'completed');

  final baseSteps = [
    (
      id: 'validation',
      label: assignmentConfirmed ? 'Vuelo validado' : 'Validar vuelo',
      complete: assignmentConfirmed,
    ),
    (
      id: 'preparation',
      label: 'Preparación',
      complete: preparationSummary.isComplete,
    ),
    (
      id: 'checklist',
      label: 'Checklist pre-vuelo',
      complete: preflightSummary.isComplete,
    ),
    (id: 'tracking', label: 'Seguimiento', complete: trackingComplete),
    (
      id: 'closure',
      label: 'Checklist post-vuelo',
      complete: postflightSummary.isComplete,
    ),
  ];

  var previousStepsComplete = true;
  var currentFound = false;
  return baseSteps.map((step) {
    late final String status;
    if (!previousStepsComplete) {
      status = 'blocked';
    } else if (step.complete) {
      status = 'completed';
    } else if (!currentFound) {
      status = 'current';
      currentFound = true;
    } else {
      status = 'available';
    }
    previousStepsComplete = previousStepsComplete && step.complete;
    return CrewOperationStepState(
      id: step.id,
      label: step.label,
      status: status,
      available: status != 'blocked',
      complete: status == 'completed',
    );
  }).toList();
}

CrewOperationPrimaryAction _buildPrimaryAction({
  required String currentStepId,
  required bool assignmentConfirmed,
  required CrewOperationChecklistSummary preparationSummary,
  required CrewOperationChecklistSummary preflightSummary,
  required CrewOperationChecklistSummary postflightSummary,
  required List<CrewOperationTrackingMilestone> trackingMilestones,
  required List<Map<String, dynamic>> allowedActions,
  required String workflowStatus,
  required bool finalReportAvailable,
}) {
  if (!assignmentConfirmed) {
    return const CrewOperationPrimaryAction(
      title: 'Acción requerida: Confirmar vuelo',
      detail:
          'Primero confirma que recibiste la asignación y que puedes operar este vuelo.',
      cta: 'Confirmar vuelo',
      kind: 'confirm_assignment',
    );
  }

  switch (currentStepId) {
    case 'preparation':
      final action = _firstAction(allowedActions, [
        _checkinMatcher,
        _cabinReadyMatcher,
      ]);
      return CrewOperationPrimaryAction(
        title: 'Siguiente paso: Completar preparación',
        detail:
            preparationSummary.total > 0
                ? 'Completa los elementos pendientes antes de continuar.'
                : 'Valida briefing, llegada, FBO y cabina antes de avanzar al resto de la operación.',
        cta: action == null ? '' : _friendlyActionLabel(action),
        kind: action == null ? 'preparation' : 'workflow_action',
        action: action,
      );
    case 'checklist':
      return CrewOperationPrimaryAction(
        title: 'Siguiente paso: Checklist pre-vuelo',
        detail:
            preflightSummary.total > 0
                ? 'Completa los elementos pendientes antes de continuar.'
                : 'Completa el checklist pre-vuelo antes de continuar.',
        cta: 'Completar checklist pre-vuelo',
        kind: 'open_checklist',
      );
    case 'tracking':
      final currentTracking = trackingMilestones
          .cast<CrewOperationTrackingMilestone?>()
          .firstWhere((item) => item?.state == 'current', orElse: () => null);
      return CrewOperationPrimaryAction(
        title:
            'Siguiente paso: ${currentTracking?.label ?? 'Registrar seguimiento'}',
        detail:
            currentTracking?.detail ??
            'Sigue registrando hitos operativos para mantener trazabilidad clara del vuelo.',
        cta:
            currentTracking?.action == null
                ? 'Abrir seguimiento'
                : _friendlyActionLabel(currentTracking!.action!),
        kind:
            currentTracking?.action == null
                ? 'open_tracking'
                : 'workflow_action',
        action: currentTracking?.action,
      );
    case 'closure':
      if (_token(workflowStatus) == 'report pending' && !finalReportAvailable) {
        return const CrewOperationPrimaryAction(
          title: 'Siguiente paso: Finalizar operación',
          detail:
              'Cuando todo esté completo podrás cerrar tu participación operativa.',
          cta: 'Enviar cierre',
          kind: 'submit_report',
        );
      }
      return CrewOperationPrimaryAction(
        title: 'Siguiente paso: Checklist post-vuelo',
        detail:
            postflightSummary.total > 0
                ? 'Completa los elementos pendientes antes de continuar.'
                : 'Completa el checklist post-vuelo antes de continuar.',
        cta: 'Completar checklist post-vuelo',
        kind: 'open_closure',
      );
  }

  return const CrewOperationPrimaryAction(
    title: 'Operación en seguimiento',
    detail: 'No hay una acción inmediata disponible.',
    cta: '',
    kind: 'none',
  );
}

List<CrewOperationTrackingMilestone> _buildTrackingMilestones(
  List<Map<String, dynamic>> trackingEvents,
  List<Map<String, dynamic>> allowedActions,
) {
  final milestones =
      _trackingDefinitions.map((definition) {
        Map<String, dynamic>? event;
        for (final entry in trackingEvents.reversed) {
          final title = _token(entry['title']);
          final status = _token(entry['status']);
          final matchesTitle = definition.titleIncludes.any(
            (value) => title.contains(_token(value)),
          );
          final matchesStatus = definition.statuses.any(
            (value) => status.contains(_token(value)),
          );
          if (matchesTitle || matchesStatus) {
            event = entry;
            break;
          }
        }

        return CrewOperationTrackingMilestone(
          id: definition.id,
          label: definition.label,
          detail: definition.detail,
          state: event == null ? 'pending' : 'completed',
          timestamp:
              event == null
                  ? ''
                  : '${event['created_at'] ?? event['updated_at'] ?? ''}'
                      .trim(),
          action: _firstAction(allowedActions, [definition.actionMatcher]),
        );
      }).toList();

  final firstPending = milestones.indexWhere(
    (item) => item.state != 'completed',
  );
  return milestones.asMap().entries.map((entry) {
    final item = entry.value;
    final state =
        item.state == 'completed'
            ? 'completed'
            : entry.key == firstPending
            ? 'current'
            : 'pending';
    return CrewOperationTrackingMilestone(
      id: item.id,
      label: item.label,
      detail: item.detail,
      state: state,
      timestamp: item.timestamp,
      action: item.action,
    );
  }).toList();
}

Map<String, dynamic>? _firstAction(
  List<Map<String, dynamic>> actions,
  List<bool Function(Map<String, dynamic>)> matchers,
) {
  for (final action in actions) {
    for (final matcher in matchers) {
      if (matcher(action)) return action;
    }
  }
  return null;
}

bool _checkinMatcher(Map<String, dynamic> action) =>
    _token(action['type']) == 'checkin';
bool _cabinReadyMatcher(Map<String, dynamic> action) =>
    _token(action['type']) == 'cabin ready';
bool _boardingMatcher(Map<String, dynamic> action) =>
    _token(action['type']) == 'passengers ready' ||
    _token(action['status']).contains('boarding');
bool _takeoffMatcher(Map<String, dynamic> action) =>
    _token(action['status']).contains('in flight');
bool _landingMatcher(Map<String, dynamic> action) =>
    _token(action['status']).contains('landed');
bool _postflightMatcher(Map<String, dynamic> action) =>
    _token(action['status']).contains('postflight');

String _friendlyActionLabel(Map<String, dynamic> action) {
  final type = _token(action['type']);
  final status = _token(action['status']);
  if (type == 'checkin') return 'Registrar llegada';
  if (type == 'cabin ready') return 'Registrar preparación';
  if (type == 'passengers ready') return 'Confirmar pasajeros recibidos';
  if (type == 'submit report') return 'Enviar cierre';
  if (status.contains('boarding')) return 'Registrar abordaje';
  if (status.contains('in flight')) return 'Registrar despegue';
  if (status.contains('landed')) return 'Registrar aterrizaje';
  if (status.contains('postflight')) return 'Registrar desembarque';
  final label = '${action['label'] ?? ''}'.trim();
  return label.isEmpty ? 'Continuar' : label;
}

bool _isResolvedStatus(Map<String, dynamic> item) {
  final status = _token(item['status']);
  return status == 'completed' || status == 'not applicable';
}

bool _isHandledStatus(Map<String, dynamic> item) {
  final status = _token(item['status']);
  return status == 'completed' ||
      status == 'not applicable' ||
      status == 'failed';
}

String normalizeCrewChecklistType(dynamic type) {
  final value = '$type'.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

  if (value == 'preparation' || value == 'preparacion') {
    return 'preparation';
  }
  if (value == 'preflight' ||
      value == 'prevuelo' ||
      value == 'preflightchecklist') {
    return 'preflight';
  }
  if (value == 'postflight' ||
      value == 'postvuelo' ||
      value == 'postflightchecklist') {
    return 'postflight';
  }
  return value;
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String _token(dynamic value) {
  return '$value'
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll('-', ' ');
}
