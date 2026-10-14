class CoordinateValidationResult {
  const CoordinateValidationResult._({
    required this.isValid,
    required this.reason,
    required this.latitude,
    required this.longitude,
  });

  factory CoordinateValidationResult.valid({
    required double latitude,
    required double longitude,
  }) {
    return CoordinateValidationResult._(
      isValid: true,
      reason: null,
      latitude: latitude,
      longitude: longitude,
    );
  }

  factory CoordinateValidationResult.invalid(String reason) {
    return CoordinateValidationResult._(
      isValid: false,
      reason: reason,
      latitude: null,
      longitude: null,
    );
  }

  final bool isValid;
  final String? reason;
  final double? latitude;
  final double? longitude;
}

class CoordinateValidator {
  const CoordinateValidator._();

  static CoordinateValidationResult validate({
    required Object? latitude,
    required Object? longitude,
    bool rejectZeroZeroWhenSourceMissing = false,
  }) {
    final lat = _parse(latitude);
    final lng = _parse(longitude);

    if (lat == null) {
      return CoordinateValidationResult.invalid('latitud_nula_o_invalida');
    }
    if (lng == null) {
      return CoordinateValidationResult.invalid('longitud_nula_o_invalida');
    }
    if (!lat.isFinite) {
      return CoordinateValidationResult.invalid('latitud_no_finita');
    }
    if (!lng.isFinite) {
      return CoordinateValidationResult.invalid('longitud_no_finita');
    }
    if (lat < -90 || lat > 90) {
      return CoordinateValidationResult.invalid('latitud_fuera_de_rango');
    }
    if (lng < -180 || lng > 180) {
      return CoordinateValidationResult.invalid('longitud_fuera_de_rango');
    }
    if (rejectZeroZeroWhenSourceMissing && lat == 0 && lng == 0) {
      return CoordinateValidationResult.invalid(
        'coordenada_cero_cero_sospechosa',
      );
    }

    return CoordinateValidationResult.valid(latitude: lat, longitude: lng);
  }

  static double? _parse(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.trim();
      if (normalized.isEmpty) return null;
      return double.tryParse(normalized);
    }
    return null;
  }
}
  