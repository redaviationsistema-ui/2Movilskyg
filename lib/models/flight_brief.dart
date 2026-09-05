class FlightBrief {
  const FlightBrief({
    required this.flightRequestId,
    required this.visible,
    required this.payment,
    required this.flight,
    required this.departure,
    required this.arrival,
    required this.aircraft,
    required this.provider,
    required this.operation,
    required this.crew,
    required this.checklist,
    required this.readiness,
    required this.presentation,
    required this.support,
    required this.services,
    required this.legs,
  });

  final String flightRequestId;
  final bool visible;
  final FlightBriefPayment payment;
  final FlightBriefFlight flight;
  final FlightBriefLocation departure;
  final FlightBriefLocation arrival;
  final FlightBriefAircraft aircraft;
  final FlightBriefProvider provider;
  final FlightBriefOperation operation;
  final FlightBriefCrew crew;
  final FlightBriefChecklist checklist;
  final FlightBriefReadiness readiness;
  final FlightBriefPresentation presentation;
  final FlightBriefSupport support;
  final Map<String, FlightBriefService> services;
  final List<FlightBriefLeg> legs;

  bool get hasLegPresentation => legs.any((leg) => leg.hasPresentation);

  FlightBrief withLegs(List<FlightBriefLeg> value) => FlightBrief(
    flightRequestId: flightRequestId,
    visible: visible,
    payment: payment,
    flight: flight,
    departure: departure,
    arrival: arrival,
    aircraft: aircraft,
    provider: provider,
    operation: operation,
    crew: crew,
    checklist: checklist,
    readiness: readiness,
    presentation: presentation,
    support: support,
    services: services,
    legs: List.unmodifiable(value),
  );

  static List<FlightBriefLeg> legsFromPayload(Map<String, dynamic> payload) {
    final itinerary = _map(payload['itinerary']);
    final flight = _map(payload['flight']);
    return List.unmodifiable(
      _firstMapList([
        payload['legs'],
        payload['segments'],
        payload['routes'],
        itinerary['legs'],
        itinerary['segments'],
        itinerary['routes'],
        flight['legs'],
        flight['segments'],
        flight['routes'],
      ]).map(FlightBriefLeg.fromJson),
    );
  }

  factory FlightBrief.fromJson(Map<String, dynamic> json) {
    final payload =
        _map(json['flight_brief']).isNotEmpty
            ? _map(json['flight_brief'])
            : json;
    final services = _map(payload['services']).map(
      (key, value) => MapEntry(key, FlightBriefService.fromJson(_map(value))),
    );
    final flight = _map(payload['flight']);

    return FlightBrief(
      flightRequestId: _text(payload['flight_request_id']),
      visible: _bool(payload['visible']),
      payment: FlightBriefPayment.fromJson(_map(payload['payment'])),
      flight: FlightBriefFlight.fromJson(flight),
      departure: FlightBriefLocation.fromJson(_map(payload['departure'])),
      arrival: FlightBriefLocation.fromJson(_map(payload['arrival'])),
      aircraft: FlightBriefAircraft.fromJson(_map(payload['aircraft'])),
      provider: FlightBriefProvider.fromJson(_map(payload['provider'])),
      operation: FlightBriefOperation.fromJson(_map(payload['operation'])),
      crew: FlightBriefCrew.fromJson(_map(payload['crew'])),
      checklist: FlightBriefChecklist.fromJson(_map(payload['checklist'])),
      readiness: FlightBriefReadiness.fromJson(_map(payload['readiness'])),
      presentation: FlightBriefPresentation.fromJson(
        _map(payload['presentation']),
      ),
      support: FlightBriefSupport.fromJson(_map(payload['support'])),
      services: Map.unmodifiable(services),
      legs: legsFromPayload(payload),
    );
  }
}

class FlightBriefLeg {
  const FlightBriefLeg({
    required this.origin,
    required this.destination,
    required this.departureAt,
    required this.presentationLocation,
    required this.presentationAt,
    required this.presentationTime,
  });

  final FlightBriefLocation origin;
  final FlightBriefLocation destination;
  final DateTime? departureAt;
  final String presentationLocation;
  final DateTime? presentationAt;
  final String presentationTime;

  bool get hasPresentation =>
      presentationLocation.isNotEmpty ||
      presentationAt != null ||
      presentationTime.isNotEmpty;

  factory FlightBriefLeg.fromJson(Map<String, dynamic> json) {
    final presentation = _map(json['presentation']);
    return FlightBriefLeg(
      origin: _legLocation(json, 'origin', 'from'),
      destination: _legLocation(json, 'destination', 'to'),
      departureAt: _firstDate([
        json['departure_datetime'],
        json['start_datetime'],
        json['departure_at'],
        json['scheduled_at'],
      ]),
      presentationLocation: _firstText([
        presentation['location_name'],
        presentation['presentation_place'],
        json['presentation_location'],
        json['presentation_place'],
        json['presentation_point'],
      ]),
      presentationAt: _firstDate([
        presentation['presentation_datetime'],
        presentation['presentation_at'],
        json['presentation_datetime'],
        json['presentation_at'],
      ]),
      presentationTime: _firstText([
        presentation['presentation_time'],
        json['presentation_time'],
      ]),
    );
  }
}

class FlightBriefPayment {
  const FlightBriefPayment({
    required this.confirmed,
    required this.status,
    this.paidAt,
  });

  final bool confirmed;
  final String status;
  final DateTime? paidAt;

  factory FlightBriefPayment.fromJson(Map<String, dynamic> json) =>
      FlightBriefPayment(
        confirmed: _bool(json['confirmed']),
        status: _text(json['status']),
        paidAt: _date(json['paid_at']),
      );
}

class FlightBriefFlight {
  const FlightBriefFlight({
    required this.origin,
    required this.destination,
    required this.status,
    required this.aircraft,
    this.departureAt,
    this.arrivalAt,
    this.durationHours,
  });

  final String origin;
  final String destination;
  final String status;
  final String aircraft;
  final DateTime? departureAt;
  final DateTime? arrivalAt;
  final double? durationHours;

  factory FlightBriefFlight.fromJson(Map<String, dynamic> json) =>
      FlightBriefFlight(
        origin: _text(json['origin']),
        destination: _text(json['destination']),
        status: _text(json['status']),
        aircraft: _text(json['aircraft']),
        departureAt: _date(json['departure_datetime']),
        arrivalAt: _date(json['arrival_datetime']),
        durationHours: _double(json['duration_hours']),
      );
}

class FlightBriefLocation {
  const FlightBriefLocation({
    required this.code,
    required this.airportName,
    required this.city,
  });

  final String code;
  final String airportName;
  final String city;

  factory FlightBriefLocation.fromJson(Map<String, dynamic> json) =>
      FlightBriefLocation(
        code: _text(json['code']),
        airportName: _text(json['airport_name']),
        city: _text(json['city']),
      );
}

class FlightBriefAircraft {
  const FlightBriefAircraft({required this.model, required this.imageUrl});

  final String model;
  final String imageUrl;

  factory FlightBriefAircraft.fromJson(Map<String, dynamic> json) =>
      FlightBriefAircraft(
        model: _text(json['model']),
        imageUrl: _firstText([
          json['image_url'],
          json['imageUrl'],
          json['photo_url'],
          json['photoUrl'],
          json['image'],
          json['url'],
        ]),
      );
}

class FlightBriefProvider {
  const FlightBriefProvider({
    required this.assigned,
    required this.visibleName,
    required this.status,
  });

  final bool assigned;
  final String visibleName;
  final String status;

  factory FlightBriefProvider.fromJson(Map<String, dynamic> json) =>
      FlightBriefProvider(
        assigned: _bool(json['assigned']),
        visibleName: _text(json['visible_name']),
        status: _text(json['status']),
      );
}

class FlightBriefOperation {
  const FlightBriefOperation({
    required this.id,
    required this.status,
    required this.crewStatus,
  });

  final String id;
  final String status;
  final String crewStatus;

  factory FlightBriefOperation.fromJson(Map<String, dynamic> json) =>
      FlightBriefOperation(
        id: _text(json['id']),
        status: _text(json['status']),
        crewStatus: _text(json['crew_status']),
      );
}

class FlightBriefCrew {
  const FlightBriefCrew({
    required this.required,
    required this.assigned,
    required this.confirmed,
    required this.status,
    required this.visibleName,
  });

  final bool? required;
  final bool assigned;
  final bool confirmed;
  final String status;
  final String visibleName;

  factory FlightBriefCrew.fromJson(Map<String, dynamic> json) =>
      FlightBriefCrew(
        required: json['required'] == null ? null : _bool(json['required']),
        assigned: _bool(json['assigned']),
        confirmed: _bool(json['confirmed']),
        status: _text(json['status']),
        visibleName: _text(json['visible_name']),
      );
}

class FlightBriefChecklist {
  const FlightBriefChecklist({
    required this.exists,
    required this.completed,
    required this.total,
    required this.requiredCompleted,
    required this.requiredTotal,
    required this.percentage,
    required this.isComplete,
    this.submittedAt,
  });

  final bool exists;
  final int completed;
  final int total;
  final int requiredCompleted;
  final int requiredTotal;
  final double? percentage;
  final bool isComplete;
  final DateTime? submittedAt;

  factory FlightBriefChecklist.fromJson(Map<String, dynamic> json) =>
      FlightBriefChecklist(
        exists: _bool(json['exists']),
        completed: _int(json['completed']),
        total: _int(json['total']),
        requiredCompleted: _int(json['required_completed']),
        requiredTotal: _int(json['required_total']),
        percentage: _double(json['percentage']),
        isComplete: _bool(json['is_complete']),
        submittedAt: _date(json['submitted_at']),
      );
}

class FlightBriefReadiness {
  const FlightBriefReadiness({
    required this.ready,
    required this.code,
    required this.label,
  });

  final bool ready;
  final String code;
  final String label;

  factory FlightBriefReadiness.fromJson(Map<String, dynamic> json) =>
      FlightBriefReadiness(
        ready: _bool(json['ready']),
        code: _text(json['code']),
        label: _text(json['label']),
      );
}

class FlightBriefPresentation {
  const FlightBriefPresentation({
    required this.airportName,
    required this.airportCode,
    required this.city,
    required this.locationName,
    required this.address,
    required this.mapsUrl,
    required this.instructions,
    required this.isComplete,
    this.presentationAt,
  });

  final String airportName;
  final String airportCode;
  final String city;
  final String locationName;
  final String address;
  final String mapsUrl;
  final String instructions;
  final bool isComplete;
  final DateTime? presentationAt;

  bool get hasContent =>
      airportName.isNotEmpty ||
      airportCode.isNotEmpty ||
      city.isNotEmpty ||
      locationName.isNotEmpty ||
      address.isNotEmpty ||
      presentationAt != null;

  factory FlightBriefPresentation.fromJson(Map<String, dynamic> json) =>
      FlightBriefPresentation(
        airportName: _text(json['airport_name']),
        airportCode: _text(json['airport_code']),
        city: _text(json['city']),
        locationName: _text(json['location_name']),
        address: _text(json['address']),
        mapsUrl: _text(json['maps_url']),
        instructions: _text(json['instructions']),
        isComplete: _bool(json['is_complete']),
        presentationAt: _date(json['presentation_datetime']),
      );
}

class FlightBriefSupport {
  const FlightBriefSupport({
    required this.name,
    required this.phone,
    required this.whatsapp,
    required this.email,
  });

  final String name;
  final String phone;
  final String whatsapp;
  final String email;

  bool get hasContact =>
      name.isNotEmpty ||
      phone.isNotEmpty ||
      whatsapp.isNotEmpty ||
      email.isNotEmpty;

  factory FlightBriefSupport.fromJson(Map<String, dynamic> json) =>
      FlightBriefSupport(
        name: _text(json['name']),
        phone: _text(json['phone']),
        whatsapp: _text(json['whatsapp']),
        email: _text(json['email']),
      );
}

class FlightBriefService {
  const FlightBriefService({
    required this.requested,
    required this.description,
  });

  final bool requested;
  final String description;

  factory FlightBriefService.fromJson(Map<String, dynamic> json) =>
      FlightBriefService(
        requested: _bool(json['requested']),
        description: _text(json['description']),
      );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

List<Map<String, dynamic>> _firstMapList(Iterable<Object?> values) {
  for (final value in values) {
    if (value is! List) continue;
    final maps = value.whereType<Map>().map(_map).toList();
    if (maps.isNotEmpty) return maps;
  }
  return const [];
}

FlightBriefLocation _legLocation(
  Map<String, dynamic> leg,
  String primaryKey,
  String alternateKey,
) {
  final nested =
      _map(leg[primaryKey]).isNotEmpty
          ? _map(leg[primaryKey])
          : _map(leg[alternateKey]);
  return FlightBriefLocation(
    code: _firstText([
      nested['code'],
      nested['icao'],
      nested['iata'],
      leg['${primaryKey}_icao'],
      leg['${primaryKey}_iata'],
      leg[primaryKey] is String ? leg[primaryKey] : null,
      leg[alternateKey] is String ? leg[alternateKey] : null,
    ]),
    airportName: _firstText([
      nested['airport_name'],
      nested['name'],
      leg['${primaryKey}_airport_name'],
      leg['${primaryKey}_airport'],
    ]),
    city: _firstText([
      nested['city'],
      leg['${primaryKey}_city'],
      leg['${primaryKey}_municipality'],
    ]),
  );
}

String _text(Object? value) => value?.toString().trim() ?? '';

String _firstText(Iterable<Object?> values) {
  for (final value in values) {
    final text = _text(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

bool _bool(Object? value) =>
    value == true ||
    value == 1 ||
    value?.toString().toLowerCase() == 'true' ||
    value?.toString() == '1';

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse(_text(value)) ?? 0;

double? _double(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(_text(value));

DateTime? _date(Object? value) => DateTime.tryParse(_text(value));

DateTime? _firstDate(Iterable<Object?> values) {
  for (final value in values) {
    final date = _date(value);
    if (date != null) return date;
  }
  return null;
}
