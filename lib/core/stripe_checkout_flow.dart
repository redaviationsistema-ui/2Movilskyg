class ReservationCheckoutReturnContext {
  const ReservationCheckoutReturnContext({
    required this.checkoutResult,
    required this.sessionId,
    required this.reservationId,
    required this.flightRequestId,
  });

  final String checkoutResult;
  final String sessionId;
  final String reservationId;
  final String flightRequestId;

  bool get hasSessionId => isStripeCheckoutSessionId(sessionId);
  bool get isCancelled =>
      checkoutResult == 'cancel' || checkoutResult == 'cancelled';
  bool get hasReferenceIdentity =>
      hasSessionId ||
      reservationId.trim().isNotEmpty ||
      flightRequestId.trim().isNotEmpty;
}

ReservationCheckoutReturnContext parseReservationCheckoutReturn(
  Uri uri, {
  String fallbackSessionId = '',
  String fallbackReservationId = '',
  String fallbackFlightRequestId = '',
}) {
  String firstQueryValue(List<String> keys) {
    for (final key in keys) {
      final value = uri.queryParameters[key]?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  return ReservationCheckoutReturnContext(
    checkoutResult:
        (uri.queryParameters['checkout'] ?? '').trim().toLowerCase(),
    sessionId: firstQueryValue(const [
      'session_id',
      'checkout_session_id',
      'checkoutSessionId',
      'sessionId',
    ]).ifEmpty(fallbackSessionId),
    reservationId: firstQueryValue(const [
      'reservation_id',
      'reservationId',
      'booking_id',
      'bookingId',
    ]).ifEmpty(fallbackReservationId),
    flightRequestId: firstQueryValue(const [
      'flight_request_id',
      'flightRequestId',
      'request_id',
      'requestId',
    ]).ifEmpty(fallbackFlightRequestId),
  );
}

String buildReservationPaymentBackendReturnUrl({
  required String baseUrl,
  required String checkout,
  String reservationId = '',
  String flightRequestId = '',
  String scheme = 'redsky',
  String host = 'cliente',
  String path = '/pago',
}) {
  final normalizedCheckout = checkout == 'cancel' ? 'cancelled' : checkout;
  final cleanedReservationId = reservationId.trim();
  final cleanedFlightRequestId = flightRequestId.trim();
  final baseUri = Uri.tryParse(baseUrl);

  if (baseUri == null || baseUri.scheme.isEmpty || baseUri.host.isEmpty) {
    return Uri(
      scheme: scheme,
      host: host,
      path: path,
      queryParameters: {
        'checkout': normalizedCheckout,
        'session_id': '{CHECKOUT_SESSION_ID}',
        'refresh': 'flight_payment',
        if (cleanedReservationId.isNotEmpty)
          'reservation_id': cleanedReservationId,
        if (cleanedFlightRequestId.isNotEmpty)
          'flight_request_id': cleanedFlightRequestId,
      },
    ).toString();
  }

  final basePath = baseUri.path.replaceFirst(RegExp(r'/+$'), '');
  return Uri.parse(
        '${baseUri.origin}$basePath/client/flight-payment/mobile-return',
      )
      .replace(
        queryParameters: {
          'checkout': normalizedCheckout,
          'session_id': '{CHECKOUT_SESSION_ID}',
          'refresh': 'flight_payment',
          if (cleanedReservationId.isNotEmpty)
            'reservation_id': cleanedReservationId,
          if (cleanedFlightRequestId.isNotEmpty)
            'flight_request_id': cleanedFlightRequestId,
        },
      )
      .toString();
}

bool isStripeCheckoutSessionId(String? value) {
  return (value ?? '').trim().startsWith('cs_');
}

bool stripeCheckoutSessionCanBeReused(Map<String, dynamic> payload) {
  bool? firstBoolFromMaps(List<String> keys, List<Map<String, dynamic>> maps) {
    for (final map in maps) {
      for (final key in keys) {
        final value = map[key];
        if (value is bool) return value;
        final text = value?.toString().trim().toLowerCase() ?? '';
        if (text == 'true') return true;
        if (text == 'false') return false;
      }
    }
    return null;
  }

  String firstTextFromMaps(List<String> keys, List<Map<String, dynamic>> maps) {
    for (final map in maps) {
      for (final key in keys) {
        final value = map[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    return '';
  }

  Map<String, dynamic> asStringKeyMap(Object? value) {
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  final data = asStringKeyMap(payload['data']);
  final reservation = asStringKeyMap(payload['reservation']);
  final paymentOrder = asStringKeyMap(payload['payment_order']);
  final payment = asStringKeyMap(payload['payment']);
  final paymentOrderGateway = asStringKeyMap(paymentOrder['gateway_response']);
  final dataPaymentOrder = asStringKeyMap(data['payment_order']);
  final dataPaymentOrderGateway = asStringKeyMap(
    dataPaymentOrder['gateway_response'],
  );
  final checkoutSession = {
    ...asStringKeyMap(payload['checkout_session']),
    ...asStringKeyMap(payload['session']),
  };
  final dataCheckoutSession = {
    ...asStringKeyMap(data['checkout_session']),
    ...asStringKeyMap(data['session']),
  };

  final explicitReusable = firstBoolFromMaps(
    const ['checkout_reusable'],
    [
      payload,
      data,
      reservation,
      paymentOrder,
      payment,
      checkoutSession,
      dataCheckoutSession,
    ],
  );
  if (explicitReusable != null) {
    return explicitReusable;
  }

  final sessionStatus =
      firstTextFromMaps(
        const [
          'stripe_checkout_status',
          'checkout_status',
          'status',
          'session_status',
        ],
        [
          payload,
          data,
          checkoutSession,
          dataCheckoutSession,
          paymentOrderGateway,
          dataPaymentOrderGateway,
        ],
      ).toLowerCase();
  final paymentStatus =
      firstTextFromMaps(
        const [
          'stripe_checkout_payment_status',
          'stripe_payment_status',
          'payment_status',
        ],
        [
          payload,
          data,
          checkoutSession,
          dataCheckoutSession,
          paymentOrderGateway,
          dataPaymentOrderGateway,
        ],
      ).toLowerCase();

  if (const {'complete', 'completed', 'expired'}.contains(sessionStatus)) {
    return false;
  }
  if (const {'paid', 'succeeded'}.contains(paymentStatus)) {
    return false;
  }

  return true;
}

bool stripeCheckoutSessionRequiresNewCheckout(Map<String, dynamic> payload) {
  bool? firstBoolFromMaps(List<String> keys, List<Map<String, dynamic>> maps) {
    for (final map in maps) {
      for (final key in keys) {
        final value = map[key];
        if (value is bool) return value;
        final text = value?.toString().trim().toLowerCase() ?? '';
        if (text == 'true') return true;
        if (text == 'false') return false;
      }
    }
    return null;
  }

  String firstTextFromMaps(List<String> keys, List<Map<String, dynamic>> maps) {
    for (final map in maps) {
      for (final key in keys) {
        final value = map[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    return '';
  }

  Map<String, dynamic> asStringKeyMap(Object? value) {
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  final data = asStringKeyMap(payload['data']);
  final paymentOrder = asStringKeyMap(payload['payment_order']);
  final paymentOrderGateway = asStringKeyMap(paymentOrder['gateway_response']);
  final dataPaymentOrder = asStringKeyMap(data['payment_order']);
  final dataPaymentOrderGateway = asStringKeyMap(
    dataPaymentOrder['gateway_response'],
  );
  final checkoutSession = {
    ...asStringKeyMap(payload['checkout_session']),
    ...asStringKeyMap(payload['session']),
  };
  final dataCheckoutSession = {
    ...asStringKeyMap(data['checkout_session']),
    ...asStringKeyMap(data['session']),
  };

  final explicitRequiresNew = firstBoolFromMaps(
    const ['requires_new_checkout'],
    [
      payload,
      data,
      paymentOrder,
      dataPaymentOrder,
      checkoutSession,
      dataCheckoutSession,
    ],
  );
  if (explicitRequiresNew != null) {
    return explicitRequiresNew;
  }

  final sessionStatus =
      firstTextFromMaps(
        const [
          'stripe_checkout_status',
          'checkout_status',
          'status',
          'session_status',
        ],
        [
          payload,
          data,
          checkoutSession,
          dataCheckoutSession,
          paymentOrderGateway,
          dataPaymentOrderGateway,
        ],
      ).toLowerCase();

  return const {'complete', 'completed', 'expired'}.contains(sessionStatus);
}

bool shouldForceNewCheckoutAfterPendingValidation({
  required bool hadCheckoutSuccessReturn,
  required bool paymentConfirmed,
  required bool paymentPending,
  required bool hasCheckoutSessionId,
  required bool hasPaymentIntentId,
  required bool hasExplicitNewCheckoutSignal,
}) {
  if (paymentConfirmed) return false;
  if (hasExplicitNewCheckoutSignal) return true;

  return hadCheckoutSuccessReturn &&
      paymentPending &&
      hasCheckoutSessionId &&
      !hasPaymentIntentId;
}

String extractStripeCheckoutUrl(Map<String, dynamic> payload) {
  Map<String, dynamic> asStringKeyMap(Object? value) {
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  String firstTextFromMaps(List<String> keys, List<Map<String, dynamic>> maps) {
    for (final map in maps) {
      for (final key in keys) {
        final value = map[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    return '';
  }

  final data = asStringKeyMap(payload['data']);
  final reservation = asStringKeyMap(payload['reservation']);
  final paymentOrder = asStringKeyMap(payload['payment_order']);
  final payment = asStringKeyMap(payload['payment']);
  final checkoutSession = {
    ...asStringKeyMap(payload['checkout_session']),
    ...asStringKeyMap(payload['session']),
  };
  final dataReservation = asStringKeyMap(data['reservation']);
  final dataPaymentOrder = asStringKeyMap(data['payment_order']);
  final dataPayment = asStringKeyMap(data['payment']);
  final dataCheckoutSession = {
    ...asStringKeyMap(data['checkout_session']),
    ...asStringKeyMap(data['session']),
  };

  if (stripeCheckoutSessionRequiresNewCheckout(payload) ||
      !stripeCheckoutSessionCanBeReused(payload)) {
    return '';
  }

  return firstTextFromMaps(
    const [
      'checkout_url',
      'checkoutUrl',
      'management_url',
      'managementUrl',
      'payment_link',
      'paymentLink',
      'hosted_url',
      'hostedUrl',
      'url',
    ],
    [
      payload,
      data,
      reservation,
      paymentOrder,
      payment,
      checkoutSession,
      dataReservation,
      dataPaymentOrder,
      dataPayment,
      dataCheckoutSession,
    ],
  );
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback.trim() : trim();
}
