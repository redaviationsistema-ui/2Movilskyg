Map<String, dynamic>? findClientRequestByExactId(
  List<Map<String, dynamic>> requests,
  String? requestId,
) {
  final normalized = requestId?.trim() ?? '';
  if (normalized.isEmpty) return null;

  for (final request in requests) {
    final reservation = request['reservation'];
    final flightRequest = request['flight_request'];
    final ids = <String>{
      request['id']?.toString().trim() ?? '',
      request['flight_request_id']?.toString().trim() ?? '',
      request['request_id']?.toString().trim() ?? '',
      request['reservation_id']?.toString().trim() ?? '',
      request['booking_id']?.toString().trim() ?? '',
      if (reservation is Map) reservation['id']?.toString().trim() ?? '',
      if (flightRequest is Map) flightRequest['id']?.toString().trim() ?? '',
    }..remove('');
    if (ids.contains(normalized)) return request;
  }
  return null;
}

bool clientOwnsReservationPayload(
  Map<String, dynamic> payload,
  String authenticatedUserId,
) {
  final normalizedUserId = authenticatedUserId.trim();
  if (normalizedUserId.isEmpty) return false;
  final data = payload['data'];
  final reservation =
      payload['reservation'] ?? (data is Map ? data['reservation'] : null);
  final source =
      reservation is Map ? Map<String, dynamic>.from(reservation) : payload;
  final client = source['client'];
  final user = source['user'];
  final ownerId =
      source['client_id']?.toString().trim() ??
      source['user_id']?.toString().trim() ??
      (client is Map ? client['id']?.toString().trim() : null) ??
      (user is Map ? user['id']?.toString().trim() : null) ??
      '';
  return ownerId.isNotEmpty && ownerId == normalizedUserId;
}
