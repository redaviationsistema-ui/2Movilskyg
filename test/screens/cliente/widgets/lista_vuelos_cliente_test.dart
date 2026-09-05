import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/screens/cliente/widgets/lista_vuelos_cliente.dart';

void main() {
  group('Client flight primary action', () {
    test('confirmed flight opens Flight Brief', () {
      final action = resolveClientFlightPrimaryAction({
        'flight_request_id': 'req-confirmed',
        'flight_status': 'confirmed',
      });

      expect(action.type, ClientFlightPrimaryActionType.flightBrief);
      expect(action.label, 'Ver Flight Brief');
    });

    test('preparing flight opens Flight Brief', () {
      final action = resolveClientFlightPrimaryAction({
        'flight_request_id': 'req-preparing',
        'flight_status': 'en preparación',
      });

      expect(action.type, ClientFlightPrimaryActionType.flightBrief);
    });

    test('ready flight opens Flight Brief', () {
      final action = resolveClientFlightPrimaryAction({
        'flight_request_id': 'req-ready',
        'flight_status': 'ready',
      });

      expect(action.type, ClientFlightPrimaryActionType.flightBrief);
    });

    test('in-flight operation opens tracking when it is available', () {
      final action = resolveClientFlightPrimaryAction({
        'flight_request_id': 'req-live',
        'operation_id': 'operation-live',
        'flight_status': 'en vuelo',
      });

      expect(action.type, ClientFlightPrimaryActionType.tracking);
      expect(action.label, 'Ver seguimiento');
    });

    test('completed flight opens its summary', () {
      final action = resolveClientFlightPrimaryAction({
        'flight_request_id': 'req-completed',
        'flight_status': 'finalizado',
      });

      expect(action.type, ClientFlightPrimaryActionType.summary);
      expect(action.label, 'Ver resumen');
    });

    test('cancelled flight has no operational CTA', () {
      final action = resolveClientFlightPrimaryAction({
        'flight_request_id': 'req-cancelled',
        'workflow_status': 'cancelled',
      });

      expect(action.type, ClientFlightPrimaryActionType.none);
      expect(action.isOperational, isFalse);
    });

    test('operation id alone does not make tracking available', () {
      expect(
        hasClientTrackingAvailable({
          'operation_id': 'operation-not-live',
          'flight_status': 'confirmed',
        }),
        isFalse,
      );
    });
  });

  group('ClientFlightsList passenger formatting', () {
    test('passengers = 4 -> 4 pax', () {
      expect(resolveClientPassengerCount({'passengers': 4}), 4);
      expect(formatClientPassengerCompactLabel({'passengers': 4}), '4 pax');
    });

    test('passengers = 1 -> 1 pax', () {
      expect(resolveClientPassengerCount({'passengers': 1}), 1);
      expect(formatClientPassengerCompactLabel({'passengers': 1}), '1 pax');
    });

    test('missing passengers does not render 1 pax', () {
      expect(resolveClientPassengerCount({}), isNull);
      expect(formatClientPassengerCompactLabel({}), 'Pax -');
    });

    test('null passengers does not render 1 pax', () {
      expect(resolveClientPassengerCount({'passengers': null}), isNull);
      expect(formatClientPassengerCompactLabel({'passengers': null}), 'Pax -');
    });

    test('alternative passenger field is honored', () {
      expect(resolveClientPassengerCount({'num_passengers': 3}), 3);
      expect(formatClientPassengerCompactLabel({'num_passengers': 3}), '3 pax');
    });
  });
}
