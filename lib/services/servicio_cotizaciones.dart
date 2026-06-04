import '../core/cliente_api.dart';

class QuoteService {
  static Future<String> createQuote({
    required String fullName,
    required String email,
    required String phone,
    required String flightType,
    required double totalPrice,
  }) async {
    final response = await ApiClient.instance.post(
      '/cliente/solicitudes',
      authenticated: true,
      body: {
        'origin': 'PENDING',
        'destination': 'PENDING',
        'departure_datetime': DateTime.now().toIso8601String(),
        'passengers': 1,
        'trip_type': 'one_way',
        'notes':
            'Cotizacion movil: $fullName, $email, $phone, $flightType, total USD $totalPrice',
      },
    );

    return response["flight_request"]?["id"]?.toString() ?? '';
  }
}
