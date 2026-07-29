class PaymentAuthorizationState {
  const PaymentAuthorizationState({
    required this.isAuthorized,
    required this.canPay,
    required this.message,
    required this.aircraftAvailable,
    required this.blockingReasons,
    required this.invalidReason,
    required this.hasInconsistentAvailabilityPayload,
  });

  final bool isAuthorized;
  final bool canPay;
  final bool aircraftAvailable;
  final String message;
  final List<String> blockingReasons;
  final String invalidReason;
  final bool hasInconsistentAvailabilityPayload;

  factory PaymentAuthorizationState.fromBackend(Map<String, dynamic> payload) {
    final data = _map(payload['data']);
    final source = {...payload, ...data};
    final request = _map(source['request'] ?? source['flight_request']);
    final reservation = _map(source['reservation']);
    final contract = _map(source['contract']);
    final availability = _map(source['availability']);
    final paymentAvailability = _map(source['payment_availability']);
    final payment = _map(source['payment_authorization'] ?? source['payment']);
    final blockingReasons = _stringList(source['blocking_reasons']);
    final invalidReason = source['invalid_reason']?.toString().trim() ?? '';

    final requestReady =
        _explicitTrue(source, const ['request_ready', 'request_valid']) ||
        _explicitTrue(request, const ['ready_for_payment', 'is_valid']);
    final reservationReady =
        _explicitTrue(source, const [
          'reservation_ready',
          'reservation_valid',
        ]) ||
        _explicitTrue(reservation, const ['ready_for_payment', 'is_valid']);
    final nestedPaymentAvailability = _map(paymentAvailability['availability']);
    final aircraftAvailableValue =
        source['aircraft_available'] ??
        source['availability_confirmed'] ??
        availability['available'] ??
        availability['is_available'] ??
        nestedPaymentAvailability['available'] ??
        paymentAvailability['available'];
    final backendAuthorized = _parseBool(
      source['authorized'] ?? source['payment_authorized'],
    );
    final canPay = _parseBool(
      source['can_pay'] ??
          source['authorized'] ??
          payment['can_pay'] ??
          payment['authorized'],
    );
    final paymentAuthorized =
        canPay ||
        backendAuthorized ||
        _explicitTrue(source, const ['ready_for_checkout']) ||
        _explicitTrue(payment, const ['authorized', 'can_pay']);
    final contractCompleted = _contractCompleted(source, contract);
    final aircraftAvailable = _parseBool(aircraftAvailableValue);
    final backendApproved =
        backendAuthorized &&
        canPay &&
        blockingReasons.isEmpty &&
        invalidReason.isEmpty;
    final effectiveAircraftAvailable =
        backendApproved ? true : aircraftAvailable;
    final authorized =
        backendApproved ||
        (requestReady &&
            reservationReady &&
            contractCompleted &&
            effectiveAircraftAvailable &&
            paymentAuthorized);

    final backendMessage =
        source['message']?.toString().trim() ??
        source['reason']?.toString().trim() ??
        '';

    return PaymentAuthorizationState(
      isAuthorized: authorized,
      canPay: canPay,
      aircraftAvailable: effectiveAircraftAvailable,
      blockingReasons: blockingReasons,
      invalidReason: invalidReason,
      hasInconsistentAvailabilityPayload: backendApproved && !aircraftAvailable,
      message:
          authorized
              ? ''
              : backendMessage.isNotEmpty
              ? backendMessage
              : blockingReasons.isNotEmpty
              ? 'El backend reporto bloqueos para autorizar el pago.'
              : invalidReason.isNotEmpty
              ? invalidReason
              : !contractCompleted
              ? 'El backend aun no confirma el contrato de DocuSign como completed.'
              : !effectiveAircraftAvailable
              ? 'La aeronave ya no esta disponible.'
              : 'El backend aun no autoriza el pago de esta reservacion.',
    );
  }

  static bool _contractCompleted(
    Map<String, dynamic> source,
    Map<String, dynamic> contract,
  ) {
    final values = [
      source['docusign_status'],
      source['envelope_status'],
      source['contract_status'],
      contract['docusign_status'],
      contract['envelope_status'],
      contract['status'],
    ];
    return values.any(
      (value) => value?.toString().trim().toLowerCase() == 'completed',
    );
  }

  static bool _explicitTrue(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      if (_parseBool(source[key])) return true;
    }
    return false;
  }

  static bool _parseBool(dynamic value) {
    if (value == true || value == 1) return true;
    if (value == false || value == 0 || value == null) return false;
    if (value is String) {
      return const {
        'true',
        '1',
        'yes',
        'authorized',
        'available',
      }.contains(value.trim().toLowerCase());
    }
    return false;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};
}
