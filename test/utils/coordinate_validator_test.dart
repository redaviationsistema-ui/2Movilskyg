import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/utils/maps/coordinate_validator.dart';

void main() {
  group('CoordinateValidator', () {
    test('accepts valid coordinates', () {
      final result = CoordinateValidator.validate(
        latitude: '19.4361',
        longitude: '-99.0719',
      );

      expect(result.isValid, isTrue);
      expect(result.latitude, 19.4361);
      expect(result.longitude, -99.0719);
    });

    test('rejects null latitude', () {
      final result = CoordinateValidator.validate(
        latitude: null,
        longitude: -99.0719,
      );

      expect(result.isValid, isFalse);
      expect(result.reason, 'latitud_nula_o_invalida');
    });

    test('rejects null longitude', () {
      final result = CoordinateValidator.validate(
        latitude: 19.4361,
        longitude: null,
      );

      expect(result.isValid, isFalse);
      expect(result.reason, 'longitud_nula_o_invalida');
    });

    test('rejects out of range coordinates', () {
      final latitude = CoordinateValidator.validate(
        latitude: 91,
        longitude: -99.0719,
      );
      final longitude = CoordinateValidator.validate(
        latitude: 19.4361,
        longitude: -181,
      );

      expect(latitude.isValid, isFalse);
      expect(latitude.reason, 'latitud_fuera_de_rango');
      expect(longitude.isValid, isFalse);
      expect(longitude.reason, 'longitud_fuera_de_rango');
    });

    test('rejects non numeric values', () {
      final result = CoordinateValidator.validate(
        latitude: 'N/A',
        longitude: '-99.0719',
      );

      expect(result.isValid, isFalse);
      expect(result.reason, 'latitud_nula_o_invalida');
    });

    test('rejects zero zero only when source is known to be missing', () {
      final accepted = CoordinateValidator.validate(latitude: 0, longitude: 0);
      final rejected = CoordinateValidator.validate(
        latitude: 0,
        longitude: 0,
        rejectZeroZeroWhenSourceMissing: true,
      );

      expect(accepted.isValid, isTrue);
      expect(rejected.isValid, isFalse);
      expect(rejected.reason, 'coordenada_cero_cero_sospechosa');
    });
  });
}
