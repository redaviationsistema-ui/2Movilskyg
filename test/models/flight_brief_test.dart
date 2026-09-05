import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/models/flight_brief.dart';

Map<String, dynamic> flightBriefJson({
  bool visible = true,
  bool crewConfirmed = false,
  bool ready = false,
}) => {
  'success': true,
  'flight_brief': {
    'flight_request_id': 123,
    'visible': visible,
    'payment': {
      'confirmed': visible,
      'status': visible ? 'paid' : 'pending',
      'paid_at': visible ? '2026-09-12T16:30:00Z' : null,
    },
    'flight': {
      'departure_datetime': '2026-09-23T09:00:00Z',
      'arrival_datetime': null,
      'duration_hours': 1.85,
    },
    'departure': {
      'code': 'MMTO',
      'airport_name': 'Aeropuerto Internacional de Toluca',
      'city': 'Toluca',
    },
    'arrival': {
      'code': 'MMVR',
      'airport_name': 'General Heriberto Jara International Airport',
      'city': 'Veracruz',
    },
    'aircraft': {
      'model': 'Citation XLS',
      'image_url': 'https://example.test/jet.jpg',
      'registration': 'NO-EXPOSE',
    },
    'provider': {
      'assigned': true,
      'visible_name': 'Operador',
      'status': 'assigned',
    },
    'operation': {
      'id': 88,
      'status': 'confirmed',
      'crew_status': 'pending_confirmation',
    },
    'crew': {
      'required': true,
      'assigned': true,
      'confirmed': crewConfirmed,
      'status': crewConfirmed ? 'confirmed' : 'pending_confirmation',
      'visible_name': 'Sofía Herrera',
    },
    'checklist': {
      'exists': true,
      'completed': 3,
      'total': 10,
      'required_completed': 3,
      'required_total': 10,
      'percentage': 30,
      'is_complete': ready,
      'submitted_at': null,
    },
    'readiness': {
      'ready': ready,
      'code': ready ? 'ready' : 'checklist_in_progress',
      'label': ready ? 'Listo para salida.' : 'Preparación en progreso.',
    },
    'presentation': {
      'airport_name': 'Aeropuerto Internacional de Toluca',
      'airport_code': 'MMTO',
      'city': 'Toluca',
      'location_name': 'FBO · MMTO',
      'presentation_datetime': '2026-09-23T08:00:00Z',
      'address': 'Acceso norte 100',
      'maps_url': 'https://maps.example.test/fbo',
      'instructions': 'Preséntate con identificación.',
      'is_complete': true,
    },
    'support': {
      'name': 'Asistencia Sky',
      'phone': '+525500000000',
      'whatsapp': 'https://wa.me/525500000000',
      'email': 'support@example.test',
    },
    'services': {
      'catering': {'requested': true},
      'special_baggage': {'requested': false},
      'ground_transport': {'requested': true},
    },
  },
};

void main() {
  test('accepts alternate aircraft image URL fields from the payload', () {
    final brief = FlightBrief.fromJson({
      'flight_request_id': '123',
      'visible': true,
      'aircraft': {'model': 'Citation XLS', 'imageUrl': 'https://jet.test/xls'},
    });

    expect(brief.aircraft.imageUrl, 'https://jet.test/xls');
  });

  test(
    'parses a dynamic multi-leg itinerary from routes without fallbacks',
    () {
      final payload = flightBriefJson();
      final flightBrief = Map<String, dynamic>.from(
        payload['flight_brief'] as Map,
      );
      payload['flight_brief'] = flightBrief;
      flightBrief['routes'] = [
        {
          'origin_icao': 'MMTO',
          'origin_city': 'Toluca',
          'destination_icao': 'MMVR',
          'destination_city': 'Veracruz',
          'departure_datetime': '2026-09-23T09:00:00Z',
          'presentation_location': 'FBO Toluca',
          'presentation_time': '08:00',
        },
        {
          'origin_icao': 'MMVR',
          'destination_icao': 'MMUN',
          'destination_city': 'Cancún',
          'departure_datetime': '2026-09-24T10:30:00Z',
        },
      ];

      final brief = FlightBrief.fromJson(payload);

      expect(brief.legs, hasLength(2));
      expect(brief.legs.first.origin.code, 'MMTO');
      expect(brief.legs.first.destination.code, 'MMVR');
      expect(brief.legs.last.destination.city, 'Cancún');
      expect(brief.legs.first.presentationLocation, 'FBO Toluca');
      expect(brief.legs.first.presentationTime, '08:00');
      expect(brief.legs.last.origin.airportName, isEmpty);
    },
  );

  test('parses the Flight Brief endpoint envelope and client-safe fields', () {
    final brief = FlightBrief.fromJson(flightBriefJson());

    expect(brief.flightRequestId, '123');
    expect(brief.visible, isTrue);
    expect(brief.payment.confirmed, isTrue);
    expect(brief.departure.code, 'MMTO');
    expect(brief.arrival.city, 'Veracruz');
    expect(brief.presentation.mapsUrl, 'https://maps.example.test/fbo');
    expect(brief.services['catering']!.requested, isTrue);
    expect(brief.services['special_baggage']!.requested, isFalse);
    expect(brief.crew.visibleName, 'Sofía Herrera');
    expect(brief.aircraft.model, 'Citation XLS');
  });

  test(
    'preserves backend visibility and accepts null optional presentation values',
    () {
      final payload = flightBriefJson(visible: false);
      final flightBrief = Map<String, dynamic>.from(
        payload['flight_brief'] as Map,
      );
      payload['flight_brief'] = flightBrief;
      final presentation = Map<String, dynamic>.from(
        flightBrief['presentation'] as Map,
      );
      flightBrief['presentation'] = presentation;
      presentation['location_name'] = null;
      presentation['presentation_datetime'] = null;
      presentation['address'] = null;
      presentation['maps_url'] = null;
      presentation['instructions'] = null;
      payload['flight_brief']['support'] = <String, dynamic>{};

      final brief = FlightBrief.fromJson(payload);

      expect(brief.visible, isFalse);
      expect(brief.payment.confirmed, isFalse);
      expect(brief.presentation.locationName, isEmpty);
      expect(brief.presentation.presentationAt, isNull);
      expect(brief.presentation.mapsUrl, isEmpty);
      expect(brief.support.hasContact, isFalse);
    },
  );

  test(
    'parses confirmed crew and readiness without deriving another state',
    () {
      final brief = FlightBrief.fromJson(
        flightBriefJson(crewConfirmed: true, ready: true),
      );

      expect(brief.crew.confirmed, isTrue);
      expect(brief.readiness.ready, isTrue);
      expect(brief.checklist.isComplete, isTrue);
    },
  );
}
