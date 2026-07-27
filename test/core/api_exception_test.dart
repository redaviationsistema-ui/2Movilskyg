import 'package:flutter_test/flutter_test.dart';
import 'package:red_sky/core/cliente_api.dart';

void main() {
  test('recognizes 409 AIRCRAFT_NOT_AVAILABLE', () {
    const error = ApiException(
      'Conflict',
      statusCode: 409,
      payload: {'code': 'AIRCRAFT_NOT_AVAILABLE'},
    );
    expect(error.isAircraftNotAvailable, isTrue);
  });

  test('does not treat a generic 409 as aircraft unavailable', () {
    const error = ApiException('Conflict', statusCode: 409);
    expect(error.isAircraftNotAvailable, isFalse);
  });
}
