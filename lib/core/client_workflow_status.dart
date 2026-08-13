class ClientWorkflowDefinition {
  const ClientWorkflowDefinition({
    required this.id,
    required this.label,
    required this.apiStatus,
    required this.apiWorkflow,
    required this.matches,
  });

  final String id;
  final String label;
  final String apiStatus;
  final String apiWorkflow;
  final List<String> matches;
}

const List<ClientWorkflowDefinition> kClientWorkflowDefinitions = [
  ClientWorkflowDefinition(
    id: 'draft',
    label: 'Cotizacion',
    apiStatus: 'draft',
    apiWorkflow: 'borrador',
    matches: ['draft', 'borrador', 'created', 'new', 'nueva', 'nuevo'],
  ),
  ClientWorkflowDefinition(
    id: 'quoted',
    label: 'Cotizacion',
    apiStatus: 'quoted',
    apiWorkflow: 'cotizada',
    matches: ['quoted', 'cotizada', 'cotizado', 'quote', 'propuesta'],
  ),
  ClientWorkflowDefinition(
    id: 'package_selected',
    label: 'Pendiente',
    apiStatus: 'package_selected',
    apiWorkflow: 'paquete elegido',
    matches: [
      'package_selected',
      'paquete elegido',
      'paquete seleccionado',
      'service tier',
    ],
  ),
  ClientWorkflowDefinition(
    id: 'reserved',
    label: 'Reserva solicitada',
    apiStatus: 'reserved',
    apiWorkflow: 'reserva solicitada',
    matches: [
      'reserved',
      'reserva',
      'reservada',
      'reservado',
      'solicitada',
      'pending',
      'pendiente',
    ],
  ),
  ClientWorkflowDefinition(
    id: 'provider_pending',
    label: 'Esperando proveedor',
    apiStatus: 'provider_pending',
    apiWorkflow: 'proveedor por confirmar',
    matches: [
      'provider_pending',
      'buscando operador',
      'buscando aeronave',
      'matching',
      'matching en proceso',
      'in_validation',
      'en validacion',
      'revision operativa',
    ],
  ),
  ClientWorkflowDefinition(
    id: 'provider_accepted',
    label: 'Firma tu contrato',
    apiStatus: 'provider_accepted',
    apiWorkflow: 'proveedor aceptado',
    matches: [
      'provider_accepted',
      'accepted',
      'aceptada',
      'aceptado',
      'operador asignado',
      'operador_asignado',
      'operador confirmado',
      'approved',
      'aprobada',
      'aprobado',
      'matched',
    ],
  ),
  ClientWorkflowDefinition(
    id: 'contract_pending',
    label: 'Contrato pendiente',
    apiStatus: 'contract_pending',
    apiWorkflow: 'contrato pendiente',
    matches: [
      'contract_pending',
      'contrato pendiente',
      'in_contract',
      'en contrato',
      'firma pendiente',
    ],
  ),
  ClientWorkflowDefinition(
    id: 'contract_signed',
    label: 'Contrato firmado',
    apiStatus: 'contract_signed',
    apiWorkflow: 'contrato firmado',
    matches: [
      'contract_signed',
      'contrato firmado',
      'firma completada',
      'signed',
    ],
  ),
  ClientWorkflowDefinition(
    id: 'payment_pending',
    label: 'Pago pendiente',
    apiStatus: 'payment_pending',
    apiWorkflow: 'pago pendiente',
    matches: [
      'payment_pending',
      'pending_payment',
      'pago pendiente',
      'checkout',
      'payment',
    ],
  ),
  ClientWorkflowDefinition(
    id: 'payment_confirmed',
    label: 'Pago confirmado',
    apiStatus: 'payment_confirmed',
    apiWorkflow: 'pago confirmado',
    matches: ['payment_confirmed', 'paid', 'pagada', 'pagado', 'pago aprobado'],
  ),
  ClientWorkflowDefinition(
    id: 'flight_confirmed',
    label: 'Vuelo confirmado',
    apiStatus: 'flight_confirmed',
    apiWorkflow: 'vuelo confirmado',
    matches: [
      'flight_confirmed',
      'vuelo confirmado',
      'operacion confirmada',
      'confirmada',
      'confirmado',
    ],
  ),
  ClientWorkflowDefinition(
    id: 'tracking_live',
    label: 'En operacion',
    apiStatus: 'tracking_live',
    apiWorkflow: 'tracking en vivo',
    matches: [
      'tracking_live',
      'tracking',
      'en operacion',
      'en vuelo',
      'boarding',
      'briefing',
      'concierge asignado',
    ],
  ),
  ClientWorkflowDefinition(
    id: 'completed',
    label: 'Finalizado',
    apiStatus: 'completed',
    apiWorkflow: 'finalizada',
    matches: [
      'completed',
      'completada',
      'finalizada',
      'finalizado',
      'cerrada',
      'post-vuelo',
    ],
  ),
  ClientWorkflowDefinition(
    id: 'rejected',
    label: 'Vuelo rechazado',
    apiStatus: 'rejected',
    apiWorkflow: 'rechazada',
    matches: [
      'rejected',
      'rechazada',
      'rechazado',
      'declined',
      'no viable',
      'sin opciones disponibles',
      'no options available',
      'operador rechazo',
      'proveedor rechazo',
    ],
  ),
  ClientWorkflowDefinition(
    id: 'cancelled',
    label: 'Cancelada',
    apiStatus: 'cancelled',
    apiWorkflow: 'cancelada',
    matches: ['cancelled', 'cancelada', 'cancelado'],
  ),
];

const List<String> _terminalWorkflowPriority = [
  'cancelled',
  'rejected',
  'completed',
];

const List<String> _inferredWorkflowPriority = [
  'tracking_live',
  'flight_confirmed',
  'payment_confirmed',
  'payment_pending',
  'contract_signed',
  'contract_pending',
  'provider_accepted',
  'provider_pending',
  'reserved',
  'package_selected',
  'quoted',
  'draft',
];

String normalizeClientWorkflowValue(dynamic value) {
  return _canonicalWorkflowText(value?.toString() ?? '');
}

String resolveClientWorkflowStageIdFromValue(dynamic value) {
  final normalized = normalizeClientWorkflowValue(value);
  if (normalized.isEmpty) return '';

  for (final stageId in [
    ..._terminalWorkflowPriority,
    ..._inferredWorkflowPriority,
  ]) {
    final definition = clientWorkflowDefinitionById(stageId);
    if (definition != null &&
        _matchesWorkflowDefinitionExactly(normalized, definition)) {
      return definition.id;
    }
  }

  for (final stageId in [
    ..._terminalWorkflowPriority,
    ..._inferredWorkflowPriority,
  ]) {
    final definition = clientWorkflowDefinitionById(stageId);
    if (definition != null &&
        _matchesWorkflowDefinitionLoosely(normalized, definition)) {
      return definition.id;
    }
  }

  return '';
}

ClientWorkflowDefinition? clientWorkflowDefinitionById(String stageId) {
  for (final definition in kClientWorkflowDefinitions) {
    if (definition.id == stageId) return definition;
  }

  return null;
}

String clientWorkflowLabelForStage(
  String stageId, {
  String fallback = 'Reserva solicitada',
}) {
  return clientWorkflowDefinitionById(stageId)?.label ?? fallback;
}

String resolveClientWorkflowLabel(
  Map<String, dynamic> request, {
  String fallback = 'Reserva solicitada',
}) {
  final stageId = resolveClientWorkflowStage(request);
  return clientWorkflowLabelForStage(stageId, fallback: fallback);
}

String resolveClientWorkflowStage(Map<String, dynamic> request) {
  final nestedReservation = _nestedReservationRecord(request);
  final visibilityPayload = _asMap(request['visibility_payload']);
  final adminFlow = _asMap(visibilityPayload['admin_flow']);
  final briefing = _asMap(request['briefing']);
  final explicitRequestWorkflowRaw =
      _firstNonEmptyText([
        request['workflow_status'],
        request['workflow'],
        request['status'],
      ]) ??
      '';

  final explicitWorkflowRaw =
      _firstNonEmptyText([
        explicitRequestWorkflowRaw,
        nestedReservation['workflow_status'],
        nestedReservation['workflow'],
      ]) ??
      '';
  final rawWorkflow =
      _firstNonEmptyText([
        explicitWorkflowRaw,
        request['status'],
        nestedReservation['status'],
      ]) ??
      '';
  final normalizedWorkflow = normalizeClientWorkflowValue(rawWorkflow);
  final explicitRequestWorkflowId = resolveClientWorkflowStageIdFromValue(
    explicitRequestWorkflowRaw,
  );
  final explicitWorkflowId = resolveClientWorkflowStageIdFromValue(
    explicitWorkflowRaw,
  );

  final normalizedContractStatus = normalizeClientWorkflowValue(
    _firstNonEmptyText([
          _asMap(request['contract'])['status'],
          request['contract_status'],
          _asMap(nestedReservation['contract'])['status'],
          nestedReservation['contract_status'],
          request['signature_status'],
        ]) ??
        '',
  );
  final normalizedPaymentStatus = normalizeClientWorkflowValue(
    _firstNonEmptyText([
          _asMap(request['payment'])['status'],
          request['payment_status'],
          _asMap(request['payment_order'])['status'],
          _latestCollectedPaymentStatus(request),
          _asMap(nestedReservation['payment'])['status'],
          nestedReservation['payment_status'],
          request['checkout_status'],
        ]) ??
        '',
  );
  final normalizedRequestPaymentStatus = normalizeClientWorkflowValue(
    _firstNonEmptyText([
          _asMap(request['payment'])['status'],
          request['payment_status'],
          _asMap(request['payment_order'])['status'],
          _latestCollectedPaymentStatus(request),
          request['checkout_status'],
        ]) ??
        '',
  );
  final normalizedReservationStatus = normalizeClientWorkflowValue(
    _firstNonEmptyText([
          request['reservation_status'],
          request['reservationStatus'],
          nestedReservation['reservation_status'],
          nestedReservation['reservationStatus'],
        ]) ??
        '',
  );
  final normalizedFlightStatus = normalizeClientWorkflowValue(
    _firstNonEmptyText([
          request['flight_status'],
          request['flightStatus'],
          _asMap(request['operation'])['flight_status'],
          _asMap(request['operation'])['flightStatus'],
          nestedReservation['flight_status'],
          nestedReservation['flightStatus'],
          _asMap(nestedReservation['operation'])['flight_status'],
          _asMap(nestedReservation['operation'])['flightStatus'],
        ]) ??
        '',
  );
  final normalizedTrackingStatus = normalizeClientWorkflowValue(
    _firstNonEmptyText([
          request['tracking_status'],
          request['trackingStatus'],
          _asMap(request['operation'])['tracking_status'],
          _asMap(request['operation'])['trackingStatus'],
          request['tracking'],
          nestedReservation['tracking_status'],
          nestedReservation['trackingStatus'],
          _asMap(nestedReservation['operation'])['tracking_status'],
          _asMap(nestedReservation['operation'])['trackingStatus'],
          request['monitoring_status'],
        ]) ??
        '',
  );
  final normalizedCrewStatus = normalizeClientWorkflowValue(
    _firstNonEmptyText([
          request['crew_status'],
          request['crewStatus'],
          _asMap(request['operation'])['crew_status'],
          _asMap(request['operation'])['crewStatus'],
          nestedReservation['crew_status'],
          nestedReservation['crewStatus'],
          _asMap(nestedReservation['operation'])['crew_status'],
          _asMap(nestedReservation['operation'])['crewStatus'],
        ]) ??
        '',
  );

  final hasExplicitAssignedProvider = _hasWorkflowValue(
    request['assigned_provider_id'],
  );
  final hasExplicitAssignedAircraft = _hasWorkflowValue(
    request['assigned_aircraft_id'],
  );
  final hasSelectedProvider = _hasWorkflowValue(request['provider_id']);
  final hasSelectedAircraft = _hasWorkflowValue(request['aircraft_id']);
  final hasSelectedMatch =
      _hasWorkflowValue(request['match_id']) ||
      _hasWorkflowValue(request['matched_option_id']);
  final hasOperation =
      _hasWorkflowValue(_asMap(request['operation'])['id']) ||
      _hasWorkflowValue(request['operation_id']) ||
      _hasWorkflowValue(_asMap(nestedReservation['operation'])['id']) ||
      _hasWorkflowValue(nestedReservation['operation_id']) ||
      _hasWorkflowValue(_firstListMapValue(request['operaciones'], 'id'));
  final hasAssignedCrew =
      _hasWorkflowValue(request['crew_id']) ||
      _hasWorkflowValue(request['sobrecargo_id']) ||
      _hasWorkflowValue(request['crew_member_id']) ||
      _hasWorkflowValue(_asMap(request['sobrecargo'])['id']) ||
      _hasWorkflowValue(request['crew_name']) ||
      _hasWorkflowValue(request['crew']) ||
      _hasWorkflowValue(nestedReservation['crew_id']) ||
      _hasWorkflowValue(nestedReservation['sobrecargo_id']) ||
      _hasWorkflowValue(nestedReservation['crew_name']);
  final hasBriefingSignal =
      _hasWorkflowValue(request['briefing_time']) ||
      _hasWorkflowValue(request['presentation_time']) ||
      _hasWorkflowValue(request['presentation_place']) ||
      _hasWorkflowValue(request['presentation_location']) ||
      _hasWorkflowValue(nestedReservation['briefing_time']) ||
      _hasWorkflowValue(nestedReservation['presentation_time']) ||
      _hasWorkflowValue(nestedReservation['presentation_place']) ||
      _hasWorkflowValue(nestedReservation['presentation_location']) ||
      _hasWorkflowValue(adminFlow['presentation_time']) ||
      _hasWorkflowValue(adminFlow['presentation_place']) ||
      _hasWorkflowValue(briefing['hora_presentacion']) ||
      _hasWorkflowValue(briefing['lugar_presentacion']);
  final hasTrackingReadinessSignals =
      hasOperation && (hasAssignedCrew || hasBriefingSignal);

  final matches = _listRequestMatches(request);
  final hasAcceptedMatch = _pickAcceptedRequestMatch(request).isNotEmpty;
  final hasRejectedMatch = matches.any(
    (match) => _isOneOf(_firstMatchStatus(match), const [
      'rejected',
      'rechazada',
      'rechazado',
      'declined',
    ]),
  );
  final hasPendingMatch = matches.any(
    (match) => _isOneOf(_firstMatchStatus(match), const [
      'pending',
      'pendiente',
      'sent to provider',
      'sent_to_provider',
    ]),
  );
  final hasPendingProviderDecision = _hasPendingProviderDecisionSignal(
    request,
    nestedReservation: nestedReservation,
    visibilityPayload: visibilityPayload,
    adminFlow: adminFlow,
  );

  if (_isOneOf(normalizedReservationStatus, const [
    'closed',
    'cerrada',
    'cerrado',
    'archived',
    'archive',
  ])) {
    return 'completed';
  }

  if (_isOneOf(normalizedTrackingStatus, const [
        'completed',
        'complete',
        'finalized',
        'finalizada',
        'finalizado',
        'landed',
        'done',
      ]) ||
      _isOneOf(normalizedFlightStatus, const [
        'completed',
        'complete',
        'finalized',
        'finalizada',
        'finalizado',
        'landed',
        'done',
      ])) {
    return 'completed';
  }

  if (_isOneOf(normalizedCrewStatus, const [
    'crew completed',
    'crew_completed',
  ])) {
    return 'completed';
  }

  if (_isOneOf(normalizedTrackingStatus, const [
    'active',
    'activo',
    'activa',
    'live',
    'tracking live',
    'tracking en vivo',
    'in progress',
    'en curso',
  ])) {
    return 'tracking_live';
  }

  if (_isOneOf(normalizedFlightStatus, const [
    'confirmed',
    'confirmada',
    'confirmado',
    'flight confirmed',
    'vuelo confirmado',
    'ready',
    'lista',
    'scheduled',
  ])) {
    return 'flight_confirmed';
  }

  if (hasPendingProviderDecision &&
      !_isOneOf(normalizedPaymentStatus, const [
        'paid',
        'pagado',
        'pagada',
        'payment confirmed',
        'payment_confirmed',
      ]) &&
      !_isOneOf(normalizedContractStatus, const [
        'generated',
        'en firma',
        'firma pendiente',
        'signed',
      ])) {
    return 'provider_pending';
  }

  if (const [
        'contract_pending',
        'contract_signed',
        'payment_pending',
      ].contains(explicitRequestWorkflowId) &&
      !_isOneOf(normalizedRequestPaymentStatus, const [
        'paid',
        'pagado',
        'pagada',
        'payment confirmed',
        'payment_confirmed',
      ])) {
    return explicitRequestWorkflowId;
  }

  if (_isOneOf(normalizedPaymentStatus, const [
        'paid',
        'pagado',
        'pagada',
        'payment confirmed',
        'payment_confirmed',
      ]) &&
      const [
        'provider_pending',
        'provider_accepted',
        'contract_signed',
        'payment_pending',
      ].contains(explicitWorkflowId)) {
    return 'payment_confirmed';
  }

  if (_isOneOf(normalizedPaymentStatus, const [
        'pending',
        'pendiente',
        'pendiente de pago',
        'payment pending',
        'payment_pending',
        'requires payment method',
        'requires_payment_method',
      ]) &&
      explicitWorkflowId == 'contract_signed') {
    return 'payment_pending';
  }

  if (const [
    'contract_pending',
    'payment_confirmed',
    'flight_confirmed',
    'tracking_live',
    'completed',
    'cancelled',
    'rejected',
  ].contains(explicitWorkflowId)) {
    return explicitWorkflowId;
  }

  if (hasTrackingReadinessSignals &&
      (const [
            'payment_confirmed',
            'flight_confirmed',
          ].contains(explicitWorkflowId) ||
          _isOneOf(normalizedWorkflow, const [
            'payment confirmed',
            'pago confirmado',
            'flight confirmed',
            'vuelo confirmado',
          ]) ||
          (_isOneOf(normalizedPaymentStatus, const [
                'paid',
                'pagado',
                'pagada',
                'payment confirmed',
                'payment_confirmed',
              ]) &&
              normalizedContractStatus == 'signed'))) {
    return 'tracking_live';
  }

  final normalizedWorkflowStage = resolveClientWorkflowStageIdFromValue(
    rawWorkflow,
  );
  if (const [
    'contract_pending',
    'contract_signed',
    'payment_pending',
    'payment_confirmed',
    'flight_confirmed',
    'tracking_live',
    'completed',
    'cancelled',
    'rejected',
  ].contains(normalizedWorkflowStage)) {
    return normalizedWorkflowStage;
  }

  if (_isOneOf(normalizedPaymentStatus, const [
    'paid',
    'pagado',
    'pagada',
    'payment confirmed',
    'payment_confirmed',
  ])) {
    return 'payment_confirmed';
  }

  if (_isOneOf(normalizedPaymentStatus, const [
        'pending',
        'pendiente',
        'pendiente de pago',
        'payment pending',
        'payment_pending',
        'requires payment method',
        'requires_payment_method',
      ]) &&
      normalizedContractStatus == 'signed') {
    return 'payment_pending';
  }

  if (normalizedContractStatus == 'signed') {
    return 'contract_signed';
  }

  if (_isOneOf(normalizedContractStatus, const [
    'generated',
    'en firma',
    'firma pendiente',
  ])) {
    return 'contract_pending';
  }

  if (_isOneOf(normalizedWorkflow, const [
    'rejected',
    'rechazada',
    'rechazado',
    'declined',
    'sin opciones disponibles',
    'no options available',
  ])) {
    return 'rejected';
  }

  if (_isOneOf(normalizedWorkflow, const [
    'aceptada',
    'aceptado',
    'accepted',
    'approved',
    'aprobada',
    'aprobado',
    'provider accepted',
    'provider_accepted',
    'operador confirmado',
    'matched',
  ])) {
    return 'provider_accepted';
  }

  if (hasOperation) {
    return 'contract_pending';
  }

  if (_isOneOf(normalizedWorkflow, const [
    'provider pending',
    'provider_pending',
    'buscando operador',
    'buscando aeronave',
    'matching',
    'matching en proceso',
    'in validation',
    'en validacion',
    'revision operativa',
    'operador asignado',
  ])) {
    return 'provider_pending';
  }

  if (_isOneOf(normalizedWorkflow, const ['confirmada', 'confirmado'])) {
    if (hasExplicitAssignedProvider ||
        hasExplicitAssignedAircraft ||
        hasOperation) {
      return 'provider_accepted';
    }
    return 'provider_pending';
  }

  if (hasRejectedMatch && !hasAcceptedMatch && !hasPendingMatch) {
    return 'rejected';
  }

  if (hasAcceptedMatch && normalizedWorkflow.isEmpty) {
    return 'provider_accepted';
  }

  if ((hasSelectedProvider || hasSelectedAircraft || hasSelectedMatch) &&
      normalizedWorkflow.isEmpty) {
    return 'provider_pending';
  }

  if ((hasExplicitAssignedProvider || hasExplicitAssignedAircraft) &&
      normalizedWorkflow.isEmpty) {
    return 'provider_pending';
  }

  if (_isGenericActiveWorkflow(normalizedWorkflow)) {
    return 'reserved';
  }

  if (normalizedWorkflowStage.isNotEmpty) {
    return normalizedWorkflowStage;
  }

  return rawWorkflow.trim().isEmpty ? 'draft' : 'draft';
}

bool _hasPendingProviderDecisionSignal(
  Map<String, dynamic> request, {
  required Map<String, dynamic> nestedReservation,
  required Map<String, dynamic> visibilityPayload,
  required Map<String, dynamic> adminFlow,
}) {
  final candidateTexts = <String>[
    _firstNonEmptyText([
          request['next_action'],
          request['nextStep'],
          request['action_required'],
          request['workflow_label'],
          request['workflow_status_label'],
          request['status_label'],
          request['visible_stage'],
          request['visibleStage'],
          request['stage_label'],
          request['stageLabel'],
          nestedReservation['next_action'],
          nestedReservation['action_required'],
          visibilityPayload['next_action'],
          visibilityPayload['action_required'],
          visibilityPayload['visible_stage'],
          visibilityPayload['visibleStage'],
          visibilityPayload['stage_label'],
          visibilityPayload['stageLabel'],
          adminFlow['next_action'],
          adminFlow['action_required'],
          adminFlow['visible_stage'],
          adminFlow['visibleStage'],
          adminFlow['stage_label'],
          adminFlow['stageLabel'],
          adminFlow['cta_label'],
          adminFlow['ctaLabel'],
        ]) ??
        '',
  ];

  final normalized = candidateTexts
      .map(normalizeClientWorkflowValue)
      .where((value) => value.isNotEmpty)
      .join(' ');

  if (normalized.isEmpty) return false;

  return _containsAnyCanonical(normalized, const [
    'sent to provider',
    'sent_to_provider',
    'respond request',
    'responder solicitud',
    'pending accept',
    'pending acceptance',
    'pending provider response',
    'accept or reject',
    'aceptar o rechazar',
    'contraoferta',
    'counteroffer',
  ]);
}

String _canonicalWorkflowText(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}

bool _matchesWorkflowDefinitionExactly(
  String normalizedValue,
  ClientWorkflowDefinition definition,
) {
  if (_statusEquals(normalizedValue, definition.id) ||
      _statusEquals(normalizedValue, definition.apiStatus) ||
      _statusEquals(normalizedValue, definition.apiWorkflow)) {
    return true;
  }

  for (final candidate in definition.matches) {
    if (_statusEquals(normalizedValue, candidate)) return true;
  }

  return false;
}

bool _matchesWorkflowDefinitionLoosely(
  String normalizedValue,
  ClientWorkflowDefinition definition,
) {
  if (_statusContains(normalizedValue, definition.id) ||
      _statusContains(normalizedValue, definition.apiStatus) ||
      _statusContains(normalizedValue, definition.apiWorkflow)) {
    return true;
  }

  for (final candidate in definition.matches) {
    if (_statusContains(normalizedValue, candidate)) return true;
  }

  return false;
}

bool _statusEquals(String value, String candidate) {
  final normalizedCandidate = _canonicalWorkflowText(candidate);
  return normalizedCandidate.isNotEmpty && value == normalizedCandidate;
}

bool _statusContains(String value, String candidate) {
  final normalizedCandidate = _canonicalWorkflowText(candidate);
  return normalizedCandidate.length > 2 && value.contains(normalizedCandidate);
}

bool _containsAnyCanonical(String value, List<String> patterns) {
  for (final pattern in patterns) {
    if (_statusContains(value, pattern)) return true;
  }

  return false;
}

bool _isGenericActiveWorkflow(String workflow) {
  return _containsAnyCanonical(workflow, const [
    'active',
    'activa',
    'activo',
    'reserva activa',
    'reservation active',
    'en curso',
    'in progress',
    'open',
    'opened',
  ]);
}

bool _hasWorkflowValue(dynamic value) {
  if (value == null) return false;
  if (value is Map) return value.isNotEmpty;
  if (value is Iterable) return value.isNotEmpty;

  final text = value.toString().trim().toLowerCase();
  return text.isNotEmpty && text != 'null';
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

Map<String, dynamic> _nestedReservationRecord(Map<String, dynamic> record) {
  for (final key in const [
    'reservation',
    'flight_request',
    'request',
    'trip',
  ]) {
    final value = record[key];
    if (value is Map) return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

String? _firstNonEmptyText(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return null;
}

List<Map<String, dynamic>> _listRequestMatches(Map<String, dynamic> record) {
  final matches = <Map<String, dynamic>>[];

  for (final key in const ['matches', 'matched_options', 'request_matches']) {
    final value = record[key];
    if (value is List) {
      for (final item in value) {
        if (item is Map) matches.add(Map<String, dynamic>.from(item));
      }
    }
  }

  return matches;
}

List<Map<String, dynamic>> _collectRecordPayments(Map<String, dynamic> record) {
  final nestedReservation = _nestedReservationRecord(record);
  final payments = <Map<String, dynamic>>[];

  for (final source in [record['payments'], nestedReservation['payments']]) {
    if (source is List) {
      for (final item in source) {
        if (item is Map) payments.add(Map<String, dynamic>.from(item));
      }
    }
  }

  return payments;
}

String _latestCollectedPaymentStatus(Map<String, dynamic> record) {
  final payments = _collectRecordPayments(record);
  if (payments.isEmpty) return '';

  payments.sort((first, second) {
    final firstDate =
        DateTime.tryParse(
          _firstNonEmptyText([
                first['updated_at'],
                first['paid_at'],
                first['created_at'],
              ]) ??
              '',
        )?.millisecondsSinceEpoch ??
        0;
    final secondDate =
        DateTime.tryParse(
          _firstNonEmptyText([
                second['updated_at'],
                second['paid_at'],
                second['created_at'],
              ]) ??
              '',
        )?.millisecondsSinceEpoch ??
        0;
    return secondDate.compareTo(firstDate);
  });

  return payments.first['status']?.toString() ?? '';
}

String _pickAcceptedRequestMatch(Map<String, dynamic> record) {
  final match = _listRequestMatches(
    record,
  ).cast<Map<String, dynamic>?>().firstWhere(
    (item) =>
        item != null &&
        _isOneOf(_firstMatchStatus(item), const [
          'accepted',
          'aceptada',
          'aceptado',
          'approved',
          'aprobada',
          'aprobado',
        ]),
    orElse: () => null,
  );

  if (match == null) return '';
  return _firstMatchStatus(match);
}

String _firstMatchStatus(Map<String, dynamic> match) {
  return normalizeClientWorkflowValue(
    _firstNonEmptyText([
          match['status'],
          match['workflow_status'],
          match['state'],
        ]) ??
        '',
  );
}

bool _isOneOf(String value, List<String> candidates) {
  for (final candidate in candidates) {
    if (_statusEquals(value, candidate)) return true;
  }
  return false;
}

dynamic _firstListMapValue(dynamic value, String key) {
  if (value is List) {
    for (final item in value) {
      if (item is Map && item[key] != null) return item[key];
    }
  }
  return null;
}
