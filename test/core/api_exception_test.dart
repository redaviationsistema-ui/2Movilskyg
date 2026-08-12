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

  test('recognizes 409 AIRCRAFT_ALREADY_RESERVED as availability conflict', () {
    const error = ApiException(
      'Conflict',
      statusCode: 409,
      payload: {'code': 'AIRCRAFT_ALREADY_RESERVED'},
    );
    expect(error.isAircraftAvailabilityConflict, isTrue);
    expect(error.isAircraftNotAvailable, isTrue);
  });

  test('does not treat 409 with a different code as availability conflict', () {
    const error = ApiException(
      'Conflict',
      statusCode: 409,
      payload: {'code': 'PAYMENT_CONFLICT'},
    );
    expect(error.isAircraftAvailabilityConflict, isFalse);
  });

  test('does not treat 422 validation errors as availability conflict', () {
    const error = ApiException(
      'Validation failed',
      statusCode: 422,
      payload: {'code': 'VALIDATION_ERROR'},
    );
    expect(error.isAircraftAvailabilityConflict, isFalse);
  });

  test('does not treat 500 errors as availability conflict', () {
    const error = ApiException(
      'Server error',
      statusCode: 500,
      payload: {'code': 'INTERNAL_SERVER_ERROR'},
    );
    expect(error.isAircraftAvailabilityConflict, isFalse);
  });
}
