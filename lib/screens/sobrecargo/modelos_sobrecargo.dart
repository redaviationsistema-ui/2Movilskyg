part of 'pantalla_espacio_sobrecargo.dart';

class _Metric {
  const _Metric(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class CrewAssignment {
  CrewAssignment({
    required this.id,
    required this.operationId,
    required this.code,
    required this.route,
    required this.provider,
    required this.aircraft,
    required this.date,
    required this.showTime,
    required this.status,
    this.client = '',
    this.passengers = 0,
    this.serviceLevel = '',
    this.catering = '',
    this.specialRequirements = '',
    this.internalContact = '',
    this.origin = '',
    this.destination = '',
    this.rejectReason = '',
  });

  final String id;
  final String operationId;
  final String code;
  final String route;
  final String provider;
  final String aircraft;
  final DateTime date;
  final String showTime;
  final String client;
  final int passengers;
  final String serviceLevel;
  final String catering;
  final String specialRequirements;
  final String internalContact;
  final String origin;
  final String destination;
  String status;
  String rejectReason;

  factory CrewAssignment.fromJson(Map<String, dynamic> json) {
    final detail = _asMap(
      json['detail'] ?? json['operation'] ?? json['detalle'],
    );
    final briefing = _asMap(detail['briefing'] ?? json['briefing']);
    final origin =
        _firstString([
          briefing['origen'],
          json['origin'],
          detail['origin'],
          json['origen'],
        ]) ??
        '';
    final destination =
        _firstString([
          briefing['destino'],
          json['destination'],
          detail['destination'],
          json['destino'],
        ]) ??
        '';
    final route =
        _firstString([json['route'], json['ruta']]) ??
        (origin.isNotEmpty && destination.isNotEmpty
            ? '$origin -> $destination'
            : origin.isNotEmpty
            ? origin
            : destination);
    final departure =
        _firstString([
          briefing['salida'],
          json['departure_datetime'],
          json['departure_at'],
          json['started_at'],
          json['date'],
          json['fecha'],
        ]) ??
        '';
    final parsedDate = DateTime.tryParse(departure) ?? DateTime.now();
    final timeFromDeparture =
        departure.contains('T') && departure.length >= 16
            ? departure.substring(11, 16)
            : '';
    final rawStatus =
        _firstString([
          json['missionStatus'],
          json['mission_status'],
          json['crew_status'],
          detail['crew_status'],
          json['crew_status_label'],
          detail['status'],
          json['response_status'],
          json['assignment_response'],
          json['response'],
          json['status'],
        ]) ??
        'Pendiente';

    return CrewAssignment(
      id:
          _firstString([
            json['id'],
            json['assignment_id'],
            json['crew_assignment_id'],
            json['request_id'],
          ]) ??
          '',
      operationId:
          _firstString([
            json['operation_id'],
            json['operationId'],
            detail['id'],
            json['id'],
          ]) ??
          '',
      code:
          _firstString([
            json['flight'],
            json['code'],
            json['operation_code'],
            json['reference'],
            json['folio'],
          ]) ??
          'OPS',
      route: route.isEmpty ? 'Ruta pendiente' : route,
      provider:
          _firstString([
            json['provider'],
            json['provider_name'],
            json['operator'],
            json['company'],
          ]) ??
          'Proveedor',
      aircraft:
          _firstString([
            json['aircraft'],
            json['aircraft_model'],
            json['aircraft_name'],
            json['tail_number'],
            json['registration'],
          ]) ??
          'Aeronave',
      date: parsedDate,
      showTime:
          _firstString([
            json['show_time'],
            json['briefing_time'],
            json['report_time'],
            json['time'],
          ]) ??
          (timeFromDeparture.isEmpty
              ? null
              : 'Presentacion $timeFromDeparture') ??
          'TBD',
      status: normalizeStatus(rawStatus),
      client:
          _firstString([
            json['client'],
            json['client_name'],
            detail['client'],
          ]) ??
          '',
      passengers:
          int.tryParse(
            _firstString([
                  briefing['pasajeros_autorizados'],
                  json['passengers'],
                  detail['passengers'],
                ]) ??
                '',
          ) ??
          0,
      serviceLevel:
          _firstString([json['service_level'], detail['service_level']]) ?? '',
      catering: _firstString([json['catering'], detail['catering']]) ?? '',
      specialRequirements:
          _firstString([
            json['special_requirements'],
            detail['special_requirements'],
            json['notes'],
            detail['notes'],
          ]) ??
          '',
      internalContact:
          _firstString([
            json['internal_contact'],
            detail['internal_contact'],
          ]) ??
          '',
      origin: origin,
      destination: destination,
      rejectReason:
          _firstString([
            json['reject_reason'],
            json['crew_decline_reason'],
            detail['crew_decline_reason'],
          ]) ??
          '',
    );
  }

  String get backendId => operationId.isNotEmpty ? operationId : id;

  bool get isFinalized {
    final normalized = status.toLowerCase();
    return normalized.contains('final') || normalized.contains('rechaz');
  }

  bool get canRespondToAssignment {
    final normalized = status.toLowerCase();
    return normalized.contains('pend') || normalized.contains('recib');
  }

  bool get canCheckin => status == 'Confirmado';
  bool get canMarkCabinReady => status == 'En aeropuerto/base';
  bool get canReceivePassengers => status == 'Cabina revisada';
  bool get canStartService => status == 'Pasajeros recibidos';
  bool get canFinalizeService => status == 'En servicio';

  CrewMissionAction? get nextAction {
    if (canCheckin) {
      return const CrewMissionAction(
        label: 'Confirmar llegada',
        icon: Icons.how_to_reg_rounded,
        step: 'checkin',
        nextStatus: 'En aeropuerto/base',
        note: 'Check-in operativo confirmado por sobrecargo.',
      );
    }
    if (canMarkCabinReady) {
      return const CrewMissionAction(
        label: 'Cabina lista',
        icon: Icons.airline_seat_recline_normal_rounded,
        step: 'cabin_ready',
        nextStatus: 'Cabina revisada',
        note: 'Cabina, catering e insumos revisados por sobrecargo.',
      );
    }
    if (canReceivePassengers) {
      return const CrewMissionAction(
        label: 'Recibir pasajeros',
        icon: Icons.groups_rounded,
        step: 'passengers_ready',
        nextStatus: 'Pasajeros recibidos',
        note: 'Pasajeros recibidos por sobrecargo antes del vuelo.',
      );
    }
    if (canStartService) {
      return const CrewMissionAction(
        label: 'Iniciar servicio',
        icon: Icons.room_service_rounded,
        step: 'service_started',
        nextStatus: 'En servicio',
        note: 'Servicio a bordo iniciado por sobrecargo.',
      );
    }
    if (canFinalizeService) {
      return const CrewMissionAction(
        label: 'Finalizar servicio',
        icon: Icons.task_alt_rounded,
        step: 'service_finalized',
        nextStatus: 'Finalizada',
        note: 'Servicio finalizado por sobrecargo.',
      );
    }
    return null;
  }

  static String normalizeStatus(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('_', ' ');
    if (normalized.isEmpty || normalized == 'pending crew response') {
      return 'Pendiente';
    }
    if ([
      'confirmado',
      'confirmada',
      'confirmed',
      'accepted',
      'aceptado',
      'crew confirmed',
    ].contains(normalized)) {
      return 'Confirmado';
    }
    if ([
      'rechazado',
      'rejected',
      'declined',
      'crew declined',
    ].contains(normalized)) {
      return 'Rechazado';
    }
    if ([
      'solicitar revision',
      'revision',
      'review requested',
      'requested changes',
      'crew change requested',
    ].contains(normalized)) {
      return 'Solicitar revision';
    }
    if (normalized.contains('checkin') ||
        normalized.contains('aeropuerto') ||
        normalized.contains('base') ||
        normalized.contains('crew enroute')) {
      return 'En aeropuerto/base';
    }
    if (normalized.contains('cabina')) return 'Cabina revisada';
    if (normalized.contains('pasajeros')) return 'Pasajeros recibidos';
    if (normalized.contains('active') ||
        normalized.contains('servicio') ||
        normalized.contains('in progress')) {
      return 'En servicio';
    }
    if (normalized.contains('completed') ||
        normalized.contains('final') ||
        normalized.contains('cerrad')) {
      return 'Finalizada';
    }
    if (normalized.contains('prepar')) return 'Preparacion';
    return value.trim().isEmpty ? 'Pendiente' : value.trim();
  }

  static final demo = [
    CrewAssignment(
      id: 'crew-1',
      operationId: 'crew-1',
      code: 'RSK-2401',
      route: 'MMTO -> MMUN',
      provider: 'Red Sky Operador Toluca',
      aircraft: 'Citation Latitude XA-RSK',
      date: DateTime.now(),
      showTime: 'Presentacion 07:10',
      status: 'Pendiente',
    ),
    CrewAssignment(
      id: 'crew-2',
      operationId: 'crew-2',
      code: 'RSK-2407',
      route: 'MMMX -> MMSD',
      provider: 'Proveedor Bajio',
      aircraft: 'Learjet 75 XA-LRJ',
      date: DateTime.now().add(const Duration(days: 1)),
      showTime: 'Presentacion 13:40',
      status: 'Confirmado',
    ),
    CrewAssignment(
      id: 'crew-3',
      operationId: 'crew-3',
      code: 'RSK-2318',
      route: 'MMGL -> MMPR',
      provider: 'Operador Pacifico',
      aircraft: 'Phenom 300 XA-PHN',
      date: DateTime.now().subtract(const Duration(days: 6)),
      showTime: 'Finalizada 18:20',
      status: 'Finalizada',
    ),
  ];
}

class CrewMissionAction {
  const CrewMissionAction({
    required this.label,
    required this.icon,
    required this.step,
    required this.nextStatus,
    required this.note,
  });

  final String label;
  final IconData icon;
  final String step;
  final String nextStatus;
  final String note;
}

class CrewIncident {
  const CrewIncident({
    required this.title,
    required this.assignment,
    required this.status,
    required this.evidence,
  });

  final String title;
  final String assignment;
  final String status;
  final String evidence;

  factory CrewIncident.fromJson(Map<String, dynamic> json) {
    return CrewIncident(
      title: json['title']?.toString() ?? 'Incidencia',
      assignment:
          json['assignment']?.toString() ??
          json['operation_code']?.toString() ??
          'Operacion',
      status: json['status']?.toString() ?? 'Abierta',
      evidence: json['evidence']?.toString() ?? 'Sin evidencia',
    );
  }

  static const demo = [
    CrewIncident(
      title: 'Catering pendiente',
      assignment: 'RSK-2401',
      status: 'Abierta',
      evidence: 'foto_catering.jpg',
    ),
  ];
}

class CrewDocument {
  const CrewDocument({
    required this.title,
    required this.status,
    required this.expiration,
  });

  final String title;
  final String status;
  final String expiration;

  factory CrewDocument.fromJson(Map<String, dynamic> json) {
    return CrewDocument(
      title:
          json['title']?.toString() ?? json['name']?.toString() ?? 'Documento',
      status: json['status']?.toString() ?? 'Vigente',
      expiration:
          json['expiration']?.toString() ??
          json['expires_at']?.toString() ??
          'Sin vigencia',
    );
  }

  static const demo = [
    CrewDocument(
      title: 'Licencia sobrecargo',
      status: 'Vigente',
      expiration: '2027-12-31',
    ),
    CrewDocument(
      title: 'Primeros auxilios',
      status: 'Vence pronto',
      expiration: '2026-08-15',
    ),
  ];
}

class CrewBlock {
  const CrewBlock({required this.date, required this.reason});

  final DateTime date;
  final String reason;
}

class CrewAvailabilityStatus {
  const CrewAvailabilityStatus({
    required this.key,
    required this.label,
    required this.description,
    required this.color,
    this.selectable = true,
  });

  final String key;
  final String label;
  final String description;
  final Color color;
  final bool selectable;

  factory CrewAvailabilityStatus.fromJson(Map<String, dynamic> json) {
    final key = _normalizeAvailabilityKey(
      _firstString([json['clave'], json['status_key'], json['key']]) ??
          'POR_CONFIRMAR',
    );
    return CrewAvailabilityStatus(
      key: key,
      label:
          json['nombre']?.toString() ??
          json['state']?.toString() ??
          'Por confirmar',
      description: json['descripcion']?.toString() ?? '',
      color: _availabilityColor(json['color']?.toString()),
      selectable: json['seleccionable_sobrecargo'] != false,
    );
  }

  static const defaults = [
    CrewAvailabilityStatus(
      key: 'DISPONIBLE',
      label: 'Disponible',
      description: 'Disponible para asignaciones.',
      color: Color(0xFF22C55E),
    ),
    CrewAvailabilityStatus(
      key: 'DESCANSO',
      label: 'Descanso',
      description: 'Dia reservado para descanso.',
      color: Color(0xFF64748B),
    ),
    CrewAvailabilityStatus(
      key: 'NO_DISPONIBLE',
      label: 'No disponible',
      description: 'No aceptar asignaciones.',
      color: Color(0xFFEF4444),
    ),
    CrewAvailabilityStatus(
      key: 'BLOQUEO_SOLICITADO',
      label: 'Bloqueo solicitado',
      description: 'Solicitud pendiente de revision.',
      color: Color(0xFFEAB308),
    ),
  ];
}

class CrewAvailabilityRecord {
  const CrewAvailabilityRecord({
    required this.id,
    required this.date,
    required this.statusKey,
    required this.label,
    required this.color,
    required this.comment,
    required this.origin,
    required this.operationId,
  });

  final String id;
  final DateTime date;
  final String statusKey;
  final String label;
  final Color color;
  final String comment;
  final String origin;
  final String operationId;

  bool get isStored => id.isNotEmpty;
  bool get isOperation => statusKey == 'EN_OPERACION' || operationId.isNotEmpty;

  factory CrewAvailabilityRecord.fromJson(Map<String, dynamic> json) {
    final statusKey = _normalizeAvailabilityKey(
      _firstString([json['clave'], json['status_key'], json['status']]) ??
          'POR_CONFIRMAR',
    );
    return CrewAvailabilityRecord(
      id: json['id']?.toString() ?? '',
      date:
          DateTime.tryParse(
            _firstString([
                  json['fecha'],
                  json['from'],
                  json['date'],
                  json['starts_at'],
                  json['start_datetime'],
                ]) ??
                '',
          ) ??
          DateTime.now(),
      statusKey: statusKey,
      label:
          json['nombre']?.toString() ??
          json['state']?.toString() ??
          _availabilityLabel(statusKey),
      color: _availabilityColor(json['color']?.toString()),
      comment:
          json['comentario']?.toString() ?? json['motivo']?.toString() ?? '',
      origin: json['origen']?.toString() ?? 'SISTEMA',
      operationId:
          _firstString([
            json['operacion_id'],
            json['operation_id'],
            json['operationId'],
          ]) ??
          '',
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String? _firstString(Iterable<dynamic> values) {
  for (final value in values) {
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text != 'null') return text;
  }
  return null;
}

String _normalizeAvailabilityKey(String value) {
  final normalized = value.trim().toUpperCase().replaceAll('-', '_');
  switch (normalized) {
    case 'AVAILABLE':
    case 'DISPONIBLE':
      return 'DISPONIBLE';
    case 'REST':
    case 'DESCANSO':
      return 'DESCANSO';
    case 'UNAVAILABLE':
    case 'NO DISPONIBLE':
    case 'NO_DISPONIBLE':
      return 'NO_DISPONIBLE';
    case 'BLOCK_REQUESTED':
    case 'BLOQUEO SOLICITADO':
    case 'BLOQUEO_SOLICITADO':
      return 'BLOQUEO_SOLICITADO';
    case 'BLOCK_APPROVED':
    case 'BLOQUEO APROBADO':
    case 'BLOQUEO_APROBADO':
      return 'BLOQUEO_APROBADO';
    case 'IN_OPERATION':
    case 'EN OPERACION':
    case 'EN_OPERACION':
      return 'EN_OPERACION';
    default:
      return normalized.isEmpty ? 'POR_CONFIRMAR' : normalized;
  }
}

String _availabilityLabel(String key) {
  switch (key) {
    case 'DISPONIBLE':
      return 'Disponible';
    case 'DESCANSO':
      return 'Descanso';
    case 'NO_DISPONIBLE':
      return 'No disponible';
    case 'BLOQUEO_SOLICITADO':
      return 'Bloqueo solicitado';
    case 'BLOQUEO_APROBADO':
      return 'Bloqueo aprobado';
    case 'EN_OPERACION':
      return 'En operacion';
    default:
      return 'Por confirmar';
  }
}

Color _availabilityColor(String? value) {
  final normalized = (value ?? '').replaceAll('#', '').trim();
  if (normalized.length == 6) {
    final parsed = int.tryParse('FF$normalized', radix: 16);
    if (parsed != null) return Color(parsed);
  }
  return const Color(0xFFC7A253);
}
