import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/screens/cliente/widgets/lista_vuelos_cliente.dart';

void main() {
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
