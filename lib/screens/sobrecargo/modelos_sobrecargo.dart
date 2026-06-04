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
    required this.code,
    required this.route,
    required this.provider,
    required this.aircraft,
    required this.date,
    required this.showTime,
    required this.status,
    this.rejectReason = '',
  });

  final String id;
  final String code;
  final String route;
  final String provider;
  final String aircraft;
  final DateTime date;
  final String showTime;
  String status;
  String rejectReason;

  factory CrewAssignment.fromJson(Map<String, dynamic> json) {
    return CrewAssignment(
      id: json['id']?.toString() ?? json['assignment_id']?.toString() ?? '',
      code:
          json['code']?.toString() ??
          json['operation_code']?.toString() ??
          'OPS',
      route:
          json['route']?.toString() ??
          '${json['origin'] ?? ''}-${json['destination'] ?? ''}',
      provider:
          json['provider']?.toString() ??
          json['provider_name']?.toString() ??
          'Proveedor',
      aircraft:
          json['aircraft']?.toString() ??
          json['tail_number']?.toString() ??
          'Aeronave',
      date:
          DateTime.tryParse(
            json['date']?.toString() ?? json['departure_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
      showTime:
          json['show_time']?.toString() ??
          json['briefing_time']?.toString() ??
          'TBD',
      status: json['status']?.toString() ?? 'Pendiente',
      rejectReason: json['reject_reason']?.toString() ?? '',
    );
  }

  static final demo = [
    CrewAssignment(
      id: 'crew-1',
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
      code: 'RSK-2407',
      route: 'MMMX -> MMSD',
      provider: 'Proveedor Bajio',
      aircraft: 'Learjet 75 XA-LRJ',
      date: DateTime.now().add(const Duration(days: 1)),
      showTime: 'Presentacion 13:40',
      status: 'Aceptada',
    ),
    CrewAssignment(
      id: 'crew-3',
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
