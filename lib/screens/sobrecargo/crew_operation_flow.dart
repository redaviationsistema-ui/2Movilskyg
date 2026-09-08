class CrewWorkflowAction {
  const CrewWorkflowAction({
    required this.type,
    required this.label,
    this.status,
  });

  final String type;
  final String label;
  final String? status;

  factory CrewWorkflowAction.fromJson(Map<String, dynamic> json) {
    return CrewWorkflowAction(
      type: '${json['type'] ?? ''}'.trim(),
      label: '${json['label'] ?? ''}'.trim(),
      status: json['status'] == null ? null : '${json['status']}'.trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'label': label,
    if (status != null && status!.isNotEmpty) 'status': status,
  };
}

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
    required this.currentStep,
    required this.currentPhase,
    required this.nextAction,
    required this.allowedActions,
    required this.workflowInconsistent,
    required this.blockingReason,
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
  final String? currentStep;
  final String? currentPhase;
  final CrewWorkflowAction? nextAction;
  final List<CrewWorkflowAction> allowedActions;
  final bool workflowInconsistent;
  final String? blockingReason;

  CrewOperationStepState? stepById(String id) {
    for (final step in steps) {
      if (step.id == id) return step;
    }
    return null;
  }

  bool get trackingComplete =>
      trackingMilestones.isNotEmpty &&
      trackingMilestones.every((item) => item.state == 'completed');

  int get completedStepsCount =>
      steps.where((step) => step.status == 'completed').length;

  int get progressPercent =>
      steps.isEmpty ? 0 : ((completedStepsCount / steps.length) * 100).round();

  static CrewOperationFlowSnapshot fromPayload({
    required Map<String, dynamic> workflow,
    required bool canRespondToAssignment,
  }) {
    final assignmentStatus = _token(workflow['assignment_status']);
    final workflowStatus = _token(workflow['status']);
    final allowedActions = _mapList(workflow['allowed_actions'])
        .map(CrewWorkflowAction.fromJson)
        .where((action) => action.type.isNotEmpty)
        .toList();
    final nextActionValue = workflow['next_action'];
    final nextAction = nextActionValue is Map
        ? CrewWorkflowAction.fromJson(
            Map<String, dynamic>.from(nextActionValue),
          )
        : null;
    final currentStep = _nullableToken(workflow['current_step']);
    final currentPhase = _nullableToken(workflow['current_phase']);
    final workflowInconsistent = workflow['workflow_inconsistent'] == true;
    final blockingReason = _nullableText(workflow['blocking_reason']);
    final checklists = _mapList(workflow['checklists']);
    final trackingEvents = _mapList(workflow['tracking_events']);
    final finalReportAvailable = workflow['final_report'] is Map;

    List<Map<String, dynamic>> checklistsByType(String type) {
      final normalizedType = normalizeCrewChecklistType(type);
      return checklists.where((checklist) {
        return normalizeCrewChecklistType(checklist['type']) == normalizedType;
      }).toList();
    }

    final preparationSummary = CrewOperationChecklistSummary.fromChecklists(
      checklistsByType('preparation'),
    );
    final preflightSummary = CrewOperationChecklistSummary.fromChecklists(
      checklistsByType('preflight'),
    );
    final postflightSummary = CrewOperationChecklistSummary.fromChecklists(
      checklistsByType('postflight'),
    );

    final assignmentConfirmed =
        assignmentStatus == 'confirmed' || !canRespondToAssignment;

    final trackingMilestones = _buildTrackingMilestones(
      trackingEvents,
      nextAction,
    );

    final steps = _buildSteps(
      assignmentConfirmed: assignmentConfirmed,
      preparationSummary: preparationSummary,
      preflightSummary: preflightSummary,
      postflightSummary: postflightSummary,
      trackingMilestones: trackingMilestones,
      workflowStatus: workflowStatus,
      finalReportAvailable: finalReportAvailable,
      currentStep: currentStep,
    );

    final currentStepId =
        _canonicalStepId(currentStep) ??
        steps
            .firstWhere(
              (step) => step.status == 'current',
              orElse: () => steps.lastWhere(
                (step) => step.complete,
                orElse: () => steps.first,
              ),
            )
            .id;

    final primaryAction = _buildPrimaryAction(
      currentStepId: currentStepId,
      assignmentConfirmed: assignmentConfirmed,
      currentStep: currentStep,
      nextAction: nextAction,
      workflowInconsistent: workflowInconsistent,
      blockingReason: blockingReason,
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
      currentStep: currentStep,
      currentPhase: currentPhase,
      nextAction: nextAction,
      allowedActions: allowedActions,
      workflowInconsistent: workflowInconsistent,
      blockingReason: blockingReason,
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
    return fromChecklists(
      checklist == null ? const <Map<String, dynamic>>[] : [checklist],
    );
  }

  static CrewOperationChecklistSummary fromChecklists(
    List<Map<String, dynamic>> checklists,
  ) {
    final items = <Map<String, dynamic>>[];
    for (final checklist in checklists) {
      items.addAll(_mapList(checklist['items']));
    }
    final requiredItems = items
        .where((item) => item['is_required'] != false)
        .toList();
    final resolved = items.where(_isResolvedStatus).length;
    final handled = items.where(_isHandledStatus).length;
    final pending = items.length - handled;
    final failed = items
        .where((item) => _token(item['status']) == 'failed')
        .length;
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
  required String workflowStatus,
  required bool finalReportAvailable,
  required String? currentStep,
}) {
  final trackingComplete =
      trackingMilestones.isNotEmpty &&
      trackingMilestones.every((item) => item.state == 'completed');
  final closureComplete =
      finalReportAvailable || _isCrewClosureComplete(workflowStatus);

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
      id: 'arrival',
      label: 'Llegada al aeropuerto',
      complete: trackingMilestones.any(
        (item) => item.id == 'airport-arrival' && item.state == 'completed',
      ),
    ),
    (
      id: 'checklist',
      label: 'Checklist pre-vuelo',
      complete: preflightSummary.isComplete,
    ),
    (id: 'tracking', label: 'Seguimiento', complete: trackingComplete),
    (
      id: 'postflight',
      label: 'Checklist post-vuelo',
      complete: postflightSummary.isComplete,
    ),
    (id: 'closure', label: 'Cierre de operación', complete: closureComplete),
    (
      id: 'completed',
      label: 'Operación completada',
      complete:
          currentStep == 'completed' || _isCrewClosureComplete(workflowStatus),
    ),
  ];

  var previousStepsComplete = true;
  var currentFound = false;
  final canonicalStepId = _canonicalStepId(currentStep);
  return baseSteps.map((step) {
    late final String status;
    if (!previousStepsComplete) {
      status = 'locked';
    } else if (step.complete) {
      status = 'completed';
    } else if (!currentFound &&
        (canonicalStepId == null || canonicalStepId == step.id)) {
      status = 'current';
      currentFound = true;
    } else {
      status = 'pending';
    }
    previousStepsComplete = previousStepsComplete && step.complete;
    return CrewOperationStepState(
      id: step.id,
      label: step.label,
      status: status,
      available: status != 'locked',
      complete: status == 'completed',
    );
  }).toList();
}

CrewOperationPrimaryAction _buildPrimaryAction({
  required String currentStepId,
  required bool assignmentConfirmed,
  required String? currentStep,
  required CrewWorkflowAction? nextAction,
  required bool workflowInconsistent,
  required String? blockingReason,
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

  if (currentStep == 'completed') {
    return const CrewOperationPrimaryAction(
      title: 'Operación completada',
      detail: 'El flujo operativo y el reporte final ya quedaron registrados.',
      cta: '',
      kind: 'completed',
    );
  }

  if (workflowInconsistent && nextAction == null && blockingReason != null) {
    return CrewOperationPrimaryAction(
      title: 'Flujo bloqueado',
      detail: blockingReason,
      cta: '',
      kind: 'blocked',
    );
  }

  if (nextAction != null) {
    return CrewOperationPrimaryAction(
      title: nextAction.label,
      detail: 'Registra el siguiente avance de tu operación.',
      cta: nextAction.label,
      kind: nextAction.type == 'submit_report'
          ? 'submit_report'
          : 'workflow_action',
      action: nextAction.toJson(),
    );
  }

  if (currentStep == 'preflight') {
    return const CrewOperationPrimaryAction(
      title: 'Siguiente paso: Checklist pre-vuelo',
      detail: 'Completa el checklist pre-vuelo antes de continuar.',
      cta: 'Continuar checklist pre-vuelo',
      kind: 'open_checklist',
    );
  }

  if (currentStep == 'postflight') {
    return const CrewOperationPrimaryAction(
      title: 'Checklist post-vuelo',
      detail: 'Completa el checklist post-vuelo antes de cerrar la operación.',
      cta: 'Abrir checklist post-vuelo',
      kind: 'open_postflight',
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
  CrewWorkflowAction? nextAction,
) {
  final milestones = _trackingDefinitions.map((definition) {
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
      timestamp: event == null
          ? ''
          : '${event['created_at'] ?? event['updated_at'] ?? ''}'.trim(),
      action:
          nextAction != null && definition.actionMatcher(nextAction.toJson())
          ? nextAction.toJson()
          : null,
    );
  }).toList();

  final firstPending = milestones.indexWhere(
    (item) => item.state != 'completed',
  );
  return milestones.asMap().entries.map((entry) {
    final item = entry.value;
    final state = item.state == 'completed'
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

bool _isCrewClosureComplete(String workflowStatus) {
  final status = _token(workflowStatus);
  return status == 'crew completed' ||
      status == 'completed' ||
      status == 'finalized' ||
      status == 'finalizada';
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

String? _nullableToken(dynamic value) {
  final token = _token(value);
  return token.isEmpty || token == 'null' ? null : token.replaceAll(' ', '_');
}

String? _nullableText(dynamic value) {
  final text = '$value'.trim();
  return text.isEmpty || text == 'null' ? null : text;
}

String? _canonicalStepId(String? currentStep) => switch (currentStep) {
  'preparation' => 'preparation',
  'airport_arrival' => 'arrival',
  'preflight' => 'checklist',
  'tracking' => 'tracking',
  'postflight' => 'postflight',
  'closure' => 'closure',
  'completed' => 'completed',
  _ => null,
};
