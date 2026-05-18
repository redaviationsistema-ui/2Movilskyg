import '../core/api_client.dart';
import '../models/airport.dart';

class AirportService {
  static Future<List<Airport>> getAirports() async {
    final response = await ApiClient.instance.getAirports();

    return response.map<Airport>((json) => Airport.fromJson(json)).toList();
  }

  static Future<List<Airport>> getAirportsByState(String state) async {
    final response = await ApiClient.instance.getAirports();

    return response
        .where((json) => (json['state'] ?? json['ESTADO']) == state)
        .map<Airport>((json) => Airport.fromJson(json))
        .toList();
  }
}
