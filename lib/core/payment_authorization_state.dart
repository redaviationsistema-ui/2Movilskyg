class PaymentAuthorizationState {
  const PaymentAuthorizationState({
    required this.isAuthorized,
    required this.message,
    required this.aircraftAvailable,
  });

  final bool isAuthorized;
  final bool aircraftAvailable;
  final String message;

  factory PaymentAuthorizationState.fromBackend(Map<String, dynamic> payload) {
    final data = _map(payload['data']);
    final source = {...payload, ...data};
    final request = _map(source['request'] ?? source['flight_request']);
    final reservation = _map(source['reservation']);
    final contract = _map(source['contract']);
    final availability = _map(source['availability']);
    final payment = _map(source['payment_authorization'] ?? source['payment']);

    final requestReady =
        _explicitTrue(source, const ['request_ready', 'request_valid']) ||
        _explicitTrue(request, const ['ready_for_payment', 'is_valid']);
    final reservationReady =
        _explicitTrue(source, const [
          'reservation_ready',
          'reservation_valid',
        ]) ||
        _explicitTrue(reservation, const ['ready_for_payment', 'is_valid']);
    final aircraftAvailable =
        _explicitTrue(source, const [
          'aircraft_available',
          'availability_confirmed',
        ]) ||
        _explicitTrue(availability, const ['available', 'is_available']);
    final paymentAuthorized =
        _explicitTrue(source, const [
          'payment_authorized',
          'authorized',
          'can_pay',
          'ready_for_checkout',
        ]) ||
        _explicitTrue(payment, const ['authorized', 'can_pay']);
    final contractCompleted = _contractCompleted(source, contract);

    final authorized =
        requestReady &&
        reservationReady &&
        contractCompleted &&
        aircraftAvailable &&
        paymentAuthorized;
    final backendMessage =
        source['message']?.toString().trim() ??
        source['reason']?.toString().trim() ??
        '';

    return PaymentAuthorizationState(
      isAuthorized: authorized,
      aircraftAvailable: aircraftAvailable,
      message:
          authorized
              ? ''
              : backendMessage.isNotEmpty
              ? backendMessage
              : !contractCompleted
              ? 'El backend aun no confirma el contrato de DocuSign como completed.'
              : !aircraftAvailable
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
      final value = source[key];
      if (value == true || value == 1) return true;
      if (value is String &&
          const {
            'true',
            '1',
            'yes',
            'authorized',
            'available',
          }.contains(value.trim().toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};
}
